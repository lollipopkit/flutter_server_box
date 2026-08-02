package tech.lolli.toolbox

import android.content.Context
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLExt
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.os.Build

internal object ImpellerCompatibility {
    data class Result(val disableImpeller: Boolean, val reason: String)

    private const val PREFS_NAME = "graphics_compatibility"
    private const val KEY_SIGNATURE = "impeller_probe_signature"
    private const val KEY_DISABLE = "impeller_probe_disable"
    private const val KEY_REASON = "impeller_probe_reason"
    private const val PROBE_VERSION = 1

    private val adrenoVersionRegex = Regex(
        pattern = """\bAdreno(?:\s+\(TM\))?\s+(\d{3})\b""",
        option = RegexOption.IGNORE_CASE,
    )

    fun check(context: Context): Result {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return Result(false, "Flutter uses Skia below Android API 29")
        }

        val signature = "$PROBE_VERSION|${BuildConfig.VERSION_CODE}|${Build.FINGERPRINT}"
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (prefs.getString(KEY_SIGNATURE, null) == signature) {
            return Result(
                prefs.getBoolean(KEY_DISABLE, false),
                prefs.getString(KEY_REASON, "cached graphics probe result")
                    ?: "cached graphics probe result",
            )
        }

        val result = probe()
        prefs.edit()
            .putString(KEY_SIGNATURE, signature)
            .putBoolean(KEY_DISABLE, result.disableImpeller)
            .putString(KEY_REASON, result.reason)
            .apply()
        return result
    }

    private fun probe(): Result {
        var display: EGLDisplay = EGL14.EGL_NO_DISPLAY
        var onscreenContext: EGLContext = EGL14.EGL_NO_CONTEXT
        var offscreenContext: EGLContext = EGL14.EGL_NO_CONTEXT
        var offscreenSurface: EGLSurface = EGL14.EGL_NO_SURFACE

        try {
            display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
            if (display == EGL14.EGL_NO_DISPLAY) {
                return incompatible("EGL display is unavailable")
            }
            if (!EGL14.eglInitialize(display, null, 0, null, 0)) {
                return incompatible("EGL initialization failed")
            }

            var clientVersion = 3
            var samples = 4
            var onscreenConfig = chooseConfig(
                display,
                clientVersion,
                EGL14.EGL_WINDOW_BIT,
                samples,
            )
            if (onscreenConfig == null) {
                clientVersion = 2
                onscreenConfig = chooseConfig(
                    display,
                    clientVersion,
                    EGL14.EGL_WINDOW_BIT,
                    samples,
                )
            }
            if (onscreenConfig == null) {
                samples = 1
                onscreenConfig = chooseConfig(
                    display,
                    clientVersion,
                    EGL14.EGL_WINDOW_BIT,
                    samples,
                )
            }
            if (onscreenConfig == null) {
                return incompatible("Impeller onscreen EGL config is unsupported")
            }

            val offscreenConfig = chooseConfig(
                display,
                clientVersion,
                EGL14.EGL_PBUFFER_BIT,
                samples,
            ) ?: return incompatible("Impeller offscreen EGL config is unsupported")

            val contextAttributes = intArrayOf(
                EGL14.EGL_CONTEXT_CLIENT_VERSION,
                clientVersion,
                EGL14.EGL_NONE,
            )
            onscreenContext = EGL14.eglCreateContext(
                display,
                onscreenConfig,
                EGL14.EGL_NO_CONTEXT,
                contextAttributes,
                0,
            )
            if (onscreenContext == EGL14.EGL_NO_CONTEXT) {
                return incompatible("Impeller onscreen EGL context creation failed")
            }

            offscreenContext = EGL14.eglCreateContext(
                display,
                offscreenConfig,
                onscreenContext,
                contextAttributes,
                0,
            )
            if (offscreenContext == EGL14.EGL_NO_CONTEXT) {
                return incompatible("Impeller offscreen EGL context creation failed")
            }

            offscreenSurface = EGL14.eglCreatePbufferSurface(
                display,
                offscreenConfig,
                intArrayOf(
                    EGL14.EGL_WIDTH,
                    1,
                    EGL14.EGL_HEIGHT,
                    1,
                    EGL14.EGL_NONE,
                ),
                0,
            )
            if (offscreenSurface == EGL14.EGL_NO_SURFACE) {
                return incompatible("Impeller PBuffer surface creation failed")
            }
            if (!EGL14.eglMakeCurrent(
                    display,
                    offscreenSurface,
                    offscreenSurface,
                    offscreenContext,
                )) {
                return incompatible("Impeller offscreen EGL context cannot be made current")
            }

            val renderer = GLES20.glGetString(GLES20.GL_RENDERER)?.trim()
                ?: return incompatible("OpenGL renderer is unavailable")
            val glVersion = GLES20.glGetString(GLES20.GL_VERSION)?.trim() ?: "unknown"
            val adrenoVersion = adrenoVersionRegex.find(renderer)
                ?.groupValues
                ?.getOrNull(1)
                ?.toIntOrNull()
            if (adrenoVersion != null && adrenoVersion in 300..399) {
                return incompatible(
                    "$renderer has a known Impeller shader-linker crash ($glVersion)",
                )
            }

            return Result(
                false,
                "Impeller EGL probe passed: $renderer ($glVersion), GLES$clientVersion, ${samples}x MSAA",
            )
        } catch (e: RuntimeException) {
            return incompatible("Impeller EGL probe failed: ${e.message ?: e.javaClass.simpleName}")
        } finally {
            if (display != EGL14.EGL_NO_DISPLAY) {
                EGL14.eglMakeCurrent(
                    display,
                    EGL14.EGL_NO_SURFACE,
                    EGL14.EGL_NO_SURFACE,
                    EGL14.EGL_NO_CONTEXT,
                )
                if (offscreenSurface != EGL14.EGL_NO_SURFACE) {
                    EGL14.eglDestroySurface(display, offscreenSurface)
                }
                if (offscreenContext != EGL14.EGL_NO_CONTEXT) {
                    EGL14.eglDestroyContext(display, offscreenContext)
                }
                if (onscreenContext != EGL14.EGL_NO_CONTEXT) {
                    EGL14.eglDestroyContext(display, onscreenContext)
                }
                EGL14.eglTerminate(display)
                EGL14.eglReleaseThread()
            }
        }
    }

    private fun chooseConfig(
        display: EGLDisplay,
        clientVersion: Int,
        surfaceType: Int,
        samples: Int,
    ): EGLConfig? {
        val attributes = mutableListOf(
            EGL14.EGL_RENDERABLE_TYPE,
            if (clientVersion >= 3) {
                EGLExt.EGL_OPENGL_ES3_BIT_KHR
            } else {
                EGL14.EGL_OPENGL_ES2_BIT
            },
            EGL14.EGL_SURFACE_TYPE,
            surfaceType,
            EGL14.EGL_RED_SIZE,
            8,
            EGL14.EGL_GREEN_SIZE,
            8,
            EGL14.EGL_BLUE_SIZE,
            8,
            EGL14.EGL_ALPHA_SIZE,
            8,
            EGL14.EGL_DEPTH_SIZE,
            24,
            EGL14.EGL_STENCIL_SIZE,
            8,
        )
        if (samples > 1) {
            attributes.add(EGL14.EGL_SAMPLE_BUFFERS)
            attributes.add(1)
            attributes.add(EGL14.EGL_SAMPLES)
            attributes.add(samples)
        }
        attributes.add(EGL14.EGL_NONE)

        val configs = arrayOfNulls<EGLConfig>(1)
        val configCount = IntArray(1)
        val success = EGL14.eglChooseConfig(
            display,
            attributes.toIntArray(),
            0,
            configs,
            0,
            configs.size,
            configCount,
            0,
        )
        if (!success || configCount[0] < 1) return null
        return configs[0]
    }

    private fun incompatible(reason: String) = Result(true, reason)
}
