// Written for ServerBox Monitor: Node-RED's settings, its release defaults
// (node_modules/node-red/settings.js of 5.0.8) with the editor behind a
// sign-in. The administrator's password hash and the credentials' key come
// from the environment the agent writes (NODE_RED_ADMIN_HASH, the bcrypt of
// the generated password; NODE_RED_CREDENTIAL_SECRET).
module.exports = {
    flowFile: "flows.json",
    flowFilePretty: true,
    credentialSecret: process.env.NODE_RED_CREDENTIAL_SECRET,

    adminAuth: {
        type: "credentials",
        users: [{ username: "admin", password: process.env.NODE_RED_ADMIN_HASH, permissions: "*" }],
    },

    uiPort: process.env.PORT || 1880,

    diagnostics: { enabled: true, ui: true },
    runtimeState: { enabled: false, ui: false },
    telemetry: {},
    logging: { console: { level: "info", metrics: false, audit: false } },
    exportGlobalContextKeys: false,
    externalModules: {},

    editorTheme: {
        palette: {},
        projects: { enabled: false, workflow: { mode: "manual" } },
        codeEditor: { lib: "monaco", options: {} },
        markdownEditor: { mermaid: { enabled: true } },
        multiplayer: { enabled: false },
    },

    functionExternalModules: true,
    globalFunctionTimeout: 0,
    functionTimeout: 0,
    functionGlobalContext: {},
    debugMaxLength: 1000,
    mqttReconnectTime: 15000,
    serialReconnectTime: 15000,
};
