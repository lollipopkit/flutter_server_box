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
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/IMG_3385.PNG">
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
- [x] SSH Connect
- [x] Server Info Store
- [x] Status Chart View
- [x] Base64/Url En/Decode
- [x] Private Key Store
- [x] Server Status Detail Page
- [x] Theme Switch
- [ ] Execute Snippet
- [ ] Migrate from `ssh2` to `dartssh2`

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
