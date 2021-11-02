# Server Monitor & Toolbox

A new Flutter project which provide a chart view to display server status data.

## ScreenShots
<table>
  <tr>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/IMG_3327.PNG">
    </td>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/IMG_3347.PNG">
    </td>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/detail.jpg">
    </td>
  </tr>
</table>
<table>
  <tr>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/IMG_3330.PNG">
    </td>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/IMG_3331.PNG">
    </td>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/IMG_3346.PNG">
    </td>
  </tr>
</table>

## Milestone
- [x] SSH connect
- [x] Server info store
- [x] Status chart view
- [x] Base64/Url En/Decode
- [x] Private key store
- [x] Server status detail page
- [x] Theme switch
- [ ] Execute snippet
- [ ] Migrate from `ssh2` to `dartssh2`
- [ ] Desktop support.

## Build
Please use `make.dart` to build.
```shell
# build android apk
./make.dart build android
# due to pub package 'ssh2' incompatibility
# can't build ios ipa through './make.dart build ios'
# more info: [https://github.com/jda258/flutter_ssh2/issues/8]
# please run below cmd to run on ios device
./make.dart run release
```

## License
`LGPL License. LollipopKit 2021`
