# Server Monitor & Toolbox

A new Flutter project which provide a chart view to display server status data and a manager toolbox.

## ScreenShots
<table>
  <tr>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/server.jpg">
    </td>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/server_detail.jpg">
    </td>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/server_edit.jpg">
    </td>
  </tr>
</table>
<table>
  <tr>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/convert.jpg">
    </td>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/ping.jpg">
    </td>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/setting.jpg">
    </td>
  </tr>
</table>
<table>
  <tr>
    <td>
	    <img width="200px" src="https://raw.githubusercontent.com/LollipopKit/flutter_server_monitor_toolbox/main/screenshots/drawer.jpg">
    </td>
  </tr>
</table>

# Support
Status|Platform 
--|--|
Full Support|Android/iOS/macOS
Support, but not tested|Windows/Linux

## Milestone
- [x] SSH connect
- [x] Server info store
- [x] Status chart view
- [x] Base64/Url En/Decode
- [x] Server status detail page
- [x] Theme switch
- [x] Migrate from `ssh2` to `dartssh2`
- [x] Desktop support
- [x] Apt manager
- [x] SFTP
- [ ] Snippet market
- [x] Docker manager

## Build
Please use `make.dart` to build.
```shell
# build android apk
./make.dart build android
# Run in release mode
./make.dart run release
```

## License
`LGPL License. LollipopKit 2021`
