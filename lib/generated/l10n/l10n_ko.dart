// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get acceptBeta => '베타 버전 업데이트 수락';

  @override
  String get addSystemPrivateKeyTip =>
      '현재 개인 키가 없습니다. 시스템 기본 키(~/.ssh/id_rsa)를 추가하시겠습니까?';

  @override
  String get added2List => '작업 목록에 추가되었습니다';

  @override
  String get askAi => 'AI에게 질문';

  @override
  String get askAiAwaitingResponse => 'AI 응답 대기 중...';

  @override
  String get askAiEndpointTip => '도메인 또는 전체 URL. 경로는 선택한 프로토콜에 따라 채워집니다.';

  @override
  String get askAiProtocolTip =>
      '자동은 Responses를 먼저, 그다음 Chat Completions를 시도합니다.';

  @override
  String get askAiCommandInserted => '명령어가 터미널에 삽입되었습니다';

  @override
  String askAiConfigMissing(Object fields) {
    return '설정에서 $fields을(를) 구성해 주세요.';
  }

  @override
  String get askAiDisclaimer => 'AI가 부정확할 수 있습니다. 적용 전에 주의 깊게 검토해 주세요.';

  @override
  String get askAiInsertTerminal => '터미널에 삽입';

  @override
  String get askAiNoResponse => '응답 없음';

  @override
  String get askAiAgentWelcome => '이 서버에서 무엇을 할까요?';

  @override
  String get askAiAgentPromptHint => '에이전트에게 점검이나 수정을 요청하세요...';

  @override
  String get askAiAnalyzeSelectionPrompt => '선택한 터미널 출력을 분석하고 무슨 일이 있었는지 설명해 줘';

  @override
  String get askAiTerminalContext => '터미널 컨텍스트';

  @override
  String get askAiReviewNeeded => '검토 필요';

  @override
  String get askAiReviewAction => '제안된 명령 검토';

  @override
  String get askAiReviewBeforeContinuing => '먼저 현재 제안을 검토하거나 거부하세요';

  @override
  String get askAiApproveRun => '승인 후 실행';

  @override
  String get askAiDecline => '거부';

  @override
  String get askAiActionDeclined => '제안된 명령이 거부되었습니다.';

  @override
  String get askAiInterrupted => '에이전트 응답이 중단되었습니다.';

  @override
  String get askAiRiskReadOnly => '읽기 전용';

  @override
  String get askAiRiskCaution => '시스템 변경';

  @override
  String get askAiRiskUnvetted => '미검증 호스트';

  @override
  String get askAiRiskDestructive => '높은 위험';

  @override
  String get askAiHighRiskConfirmTitle => '위험도가 높은 명령을 실행할까요?';

  @override
  String get askAiHighRiskConfirmBody =>
      '이 명령은 되돌리기 어려운 변경을 할 수 있습니다. 잘 확인하세요.';

  @override
  String get askAiNoCommandOutput => '명령이 출력 없이 끝났습니다.';

  @override
  String get askAiOutputTruncated => '긴 출력은 에이전트로 되돌리기 전에 잘렸습니다.';

  @override
  String get askAiAutoApproved => '자동 승인됨';

  @override
  String get askAiAutoRunSafeCommands => '읽기 전용 명령 자동 실행';

  @override
  String get askAiAutoRunSafeCommandsTip => '모델과 로컬 검사가 모두 읽기 전용이라고 판단할 때만 실행';

  @override
  String get askAiSendOnEnter => 'Enter로 보내기';

  @override
  String get askAiSendOnEnterTip =>
      'Enter로 전송, Shift+Enter로 줄바꿈. 끄면: Enter로 줄바꿈, Cmd/Ctrl+Enter로 전송.';

  @override
  String get askAiApiKeyOptional => '로컬이거나 인증이 필요 없으면 비워 두세요';

  @override
  String get askAiHistory => '대화 기록';

  @override
  String get askAiNewConversation => '새 대화';

  @override
  String get askAiNoHistory => '저장된 대화가 아직 없습니다';

  @override
  String get askAiNoHistoryMessages => '아직 메시지가 없습니다';

  @override
  String get askAiUntitledConversation => '제목 없음';

  @override
  String get askAiRenameConversation => '대화 이름 바꾸기';

  @override
  String get askAiDeleteConversationTitle => '이 대화를 삭제할까요?';

  @override
  String get askAiDeleteConversationTip => '이 기기에서 삭제합니다. 되돌릴 수 없습니다.';

  @override
  String get askAiClearHistoryTitle => '이 서버의 에이전트 기록을 지울까요?';

  @override
  String get askAiClearHistoryTip => '이 서버에 저장된 Agent 대화가 모두 삭제됩니다.';

  @override
  String get askAiRestoredReview => '이 명령은 기록에서 가져온 것입니다. 다시 검토하세요';

  @override
  String get agentWelcome => '서버들에서 무엇을 할까요?';

  @override
  String get agentWelcomeTip => 'Agent에게 문제 진단이나 운영 작업을 맡길 수 있습니다';

  @override
  String get agentPromptHint => '에이전트에게 서버 점검이나 조작을 요청하세요...';

  @override
  String get agentNoHistory => '저장된 전역 에이전트 대화가 없습니다';

  @override
  String get agentClearHistoryTitle => '전역 에이전트 기록을 지울까요?';

  @override
  String get agentClearHistoryTip => '모든 전역 에이전트 대화가 이 기기에서 삭제됩니다.';

  @override
  String get agentToolShell => '셸';

  @override
  String get agentToolReadFile => '파일 읽기';

  @override
  String get agentToolWriteFile => '파일 쓰기';

  @override
  String get agentToolFailed => '도구 실행에 실패했습니다.';

  @override
  String agentToolCallsFmt(Object count) {
    return '도구 호출 $count회';
  }

  @override
  String get agentFloat => '다른 탭 위에 띄우기';

  @override
  String get agentToolSshConnect => 'SSH 연결';

  @override
  String get agentToolSshDisconnect => 'SSH 연결 끊기';

  @override
  String get agentSshConnectTitle => '새 호스트에 연결';

  @override
  String get agentAuthMethod => '인증 방식';

  @override
  String get agentSshConnectTip => 'Agent가 SSH 연결을 원합니다. 여기에 비밀번호를 입력하세요';

  @override
  String get agentAdHocSessions => '임시 연결';

  @override
  String get agentSaveServerTitle => '서버로 저장';

  @override
  String get agentSaveServerTip => '이 호스트와 입력한 비밀번호는 이 기기에 저장됩니다';

  @override
  String get agentMonitorOptional => 'monitor 에이전트(선택)';

  @override
  String get authFailTip => '인증에 실패했습니다. 정보를 확인하세요';

  @override
  String get autoBackupConflict => '자동 백업은 한 번에 하나만 활성화할 수 있습니다.';

  @override
  String get autoConnect => '자동 연결';

  @override
  String get autoRun => '자동 실행';

  @override
  String get autoUpdateHomeWidget => '홈 위젯 자동 업데이트';

  @override
  String get availableTabs => '사용 가능한 탭';

  @override
  String get backupEncrypted => '백업이 암호화되어 있습니다';

  @override
  String get backupNotEncrypted => '백업이 암호화되어 있지 않습니다';

  @override
  String get backupPassword => '백업 비밀번호';

  @override
  String get backupPasswordRemoved => '백업 비밀번호가 제거되었습니다';

  @override
  String get backupPasswordSet => '백업 비밀번호가 설정되었습니다';

  @override
  String get backupPasswordTip =>
      '백업 파일을 암호화하기 위한 비밀번호를 설정하세요. 암호화를 비활성화하려면 비워 두세요.';

  @override
  String get backupPasswordWrong => '백업 비밀번호가 올바르지 않습니다';

  @override
  String get connectAll => '모두 연결';

  @override
  String get disconnectAll => '모두 연결 해제';

  @override
  String get distIcon => '배포판 표시';

  @override
  String distIconIntroLegal(Object fontLogos) {
    return '이 표시들은 $fontLogos에서 가져왔습니다. 표시는 이 기기가 원격 시스템에서 읽은 내용만을 나타내며, 그 내용은 틀리거나 오래된 것일 수 있고 파생본이나 재빌드, 특정 버전을 가리키지도 않습니다. 시스템을 식별할 수 없거나 해당 표시가 없으면 중립적인 도형을 표시합니다.\n\n각 표시는 해당 소유자의 상표이며, 여기서는 그것이 가리키는 시스템을 지칭하기 위해서만 사용됩니다.';
  }

  @override
  String get distIconTip => '각 서버 옆에 실행 중으로 보이는 시스템의 작은 표시를 보여줍니다';

  @override
  String get navTabMenuTip =>
      '탭을 길게 누르거나 마우스 오른쪽 버튼으로 누르면 그 안의 모든 항목을 한 번에 연결하거나 끊을 수 있습니다.';

  @override
  String nTags(Object count) {
    return '태그 $count개';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Remote backups require a non-empty backup password';

  @override
  String get monitorHttpsRequired =>
      '원격 monitor 에이전트에는 HTTPS가 필요합니다. HTTP를 허용한 경우는 예외입니다.';

  @override
  String get monitorAllowInsecureHttp => 'HTTP 허용';

  @override
  String get monitorAllowInsecureHttpTip =>
      'HTTP 외에 전송 자체가 암호화되는 신뢰할 수 있는 사설망에서만. 예를 들어 Tailscale';

  @override
  String get backupTip => '내보낸 데이터는 비밀번호로 암호화할 수 있습니다.\n안전하게 보관해 주세요.';

  @override
  String get icloudBackupStatusTitle => '백업 상태';

  @override
  String get icloudBackupStatusLoading => 'iCloud 백업 상태를 불러오는 중...';

  @override
  String get icloudBackupStatusError => 'iCloud 백업 메타데이터를 읽을 수 없습니다';

  @override
  String get icloudBackupStatusEmpty => '아직 iCloud 백업 파일이 없습니다';

  @override
  String get icloudBackupStateUploading => '업로드 중';

  @override
  String get icloudBackupStateConflict => '충돌 감지됨';

  @override
  String get icloudBackupStateUploaded => '업로드됨';

  @override
  String get icloudBackupStateWaiting => 'iCloud 대기 중';

  @override
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return '마지막 백업: $lastModified\n상태: $remoteState';
  }

  @override
  String get bgRun => '백그라운드 실행';

  @override
  String get bgRunTip =>
      '이 스위치는 프로그램이 백그라운드에서 실행을 시도한다는 의미입니다. 실제 백그라운드 실행 가능 여부는 권한 활성화 여부에 따라 다릅니다. AOSP 기반 Android ROM의 경우, 이 앱의 \"배터리 최적화\"를 비활성화해 주세요. MIUI / HyperOS의 경우, 절전 정책을 \"무제한\"으로 변경해 주세요.';

  @override
  String get clearAllStatsContent => '모든 서버 연결 통계를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';

  @override
  String get clearAllStatsTitle => '모든 통계 삭제';

  @override
  String clearServerStatsContent(Object serverName) {
    return '서버 \"$serverName\"의 연결 통계를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return '$serverName 통계 삭제';
  }

  @override
  String get clearThisServerStats => '이 서버의 통계 삭제';

  @override
  String get compactDatabase => '데이터베이스 압축';

  @override
  String compactDatabaseContent(Object size) {
    return '데이터베이스 크기: $size\n\n데이터베이스를 재구성하여 파일 크기를 줄입니다. 데이터는 삭제되지 않습니다.';
  }

  @override
  String get closeAfterSave => '저장 후 닫기';

  @override
  String get collapseUITip => 'UI의 긴 목록을 기본적으로 접을지 여부';

  @override
  String get connectionDetails => '연결 상세 정보';

  @override
  String get connectionStats => '연결 통계';

  @override
  String get connectionStatsDesc => '서버 연결 성공률 및 기록 보기';

  @override
  String get containerTrySudoTip =>
      '예: 앱에서 사용자를 aaa로 설정했지만 Docker가 root 사용자로 설치된 경우, 이 옵션을 활성화해야 합니다.';

  @override
  String get containerSudoPasswordRequired =>
      'Docker에 접근하려면 sudo 비밀번호가 필요합니다. 비밀번호를 입력해 주세요.';

  @override
  String get containerSudoPasswordIncorrect =>
      'sudo 비밀번호가 올바르지 않거나 허용되지 않습니다. 다시 시도해 주세요.';

  @override
  String get copyPath => '경로 복사';

  @override
  String get cpuViewAsProgressTip => '각 CPU 사용률을 프로그레스 바 형태로 표시합니다 (이전 스타일)';

  @override
  String get customCmd => '사용자 정의 명령어';

  @override
  String get deleteServers => '서버 일괄 삭제';

  @override
  String get deleteDirRecursive => '폴더와 그 안의 모든 항목 삭제';

  @override
  String get desktopTerminalTip => 'SSH 세션을 시작할 때 사용할 터미널 에뮬레이터를 여는 명령어입니다.';

  @override
  String get dirEmpty => '폴더가 비어 있는지 확인해 주세요.';

  @override
  String get discoverSshServers => 'SSH 서버 검색';

  @override
  String get discoveryFailed => '검색 실패';

  @override
  String get discoverySettings => '검색 설정';

  @override
  String get distro => '배포판';

  @override
  String distroSwitchTip(Object from, Object to) {
    return '$from을(를) $to(으)로 바꿉니다. $from 안에 설치한 것은 모두 삭제되고, 그 자리에 $to을(를) 내려받아 풉니다.';
  }

  @override
  String get diskHealth => '디스크 상태';

  @override
  String get displayCpuIndex => 'CPU 인덱스 표시';

  @override
  String dl2Local(Object fileName) {
    return '$fileName을(를) 로컬에 다운로드하시겠습니까?';
  }

  @override
  String get dockerEmptyRunningItems =>
      '실행 중인 컨테이너가 없습니다.\n다음과 같은 원인이 있을 수 있습니다:\n- Docker 설치 사용자와 앱에 설정된 사용자 이름이 다릅니다.\n- 환경 변수 DOCKER_HOST가 올바르게 읽히지 않았습니다. 터미널에서 `echo \$DOCKER_HOST`를 실행하여 확인할 수 있습니다.';

  @override
  String dockerImagesFmt(Object count) {
    return '이미지 $count개';
  }

  @override
  String get dockerProjectOther => '기타';

  @override
  String get dockerPruneTip => '사용하지 않는 데이터를 제거하여 디스크 공간을 확보합니다';

  @override
  String get dockerStatistics => 'Docker 통계';

  @override
  String get doubleColumnMode => '이중 열 모드';

  @override
  String get doubleColumnTip => '이 옵션은 기능만 활성화하며, 실제 적용 여부는 기기의 너비에 따라 다릅니다';

  @override
  String get editVirtKeys => '가상 키';

  @override
  String get editorHighlightTip =>
      '현재 코드 하이라이팅 성능이 이상적이지 않습니다. 성능 향상을 위해 선택적으로 끌 수 있습니다.';

  @override
  String get enableMdns => 'mDNS 활성화';

  @override
  String get enableMdnsDesc => 'mDNS/Bonjour를 사용하여 SSH 서비스 검색';

  @override
  String get envVars => '환경 변수';

  @override
  String get extraArgs => '추가 인수';

  @override
  String get fallbackSshDest => '대체 SSH 대상';

  @override
  String get fdroidReleaseTip => 'F-Droid에서 이 앱을 다운로드한 경우, 이 옵션을 끄는 것을 권장합니다.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return '파일 \'$file\'이(가) 너무 큽니다. 크기 $size, 최대 $sizeMax';
  }

  @override
  String get fileDirGone => '이 폴더는 더 이상 없습니다';

  @override
  String get fileDirGoneTip => '삭제되었거나 이름이 바뀌었습니다';

  @override
  String get fullScreen => '전체 화면';

  @override
  String get fullScreenJitter => '전체 화면 지터';

  @override
  String get fullScreenJitterHelp => '화면 번인 방지';

  @override
  String get fullScreenTip =>
      '기기를 가로 모드로 회전할 때 전체 화면 모드를 활성화하시겠습니까? 이 옵션은 서버 탭에만 적용됩니다.';

  @override
  String get githubGistIdOptional => 'Gist ID (선택 사항)';

  @override
  String get githubGistToken => 'GitHub Gist 토큰';

  @override
  String get githubGistTokenEmpty => '토큰이 비어 있습니다';

  @override
  String get goto => '이동';

  @override
  String get homeTabs => '홈 탭';

  @override
  String get homeTabsCustomizeDesc => '홈 페이지에 표시할 탭과 순서를 사용자 지정합니다';

  @override
  String get homeWidgetUrlConfig => '홈 위젯 URL 설정';

  @override
  String get ignoreCert => '인증서 무시';

  @override
  String get image => '이미지';

  @override
  String get macDmgBody =>
      'App Store는 이 앱을 샌드박스에서 실행하도록 요구하며, 샌드박스에서는 터미널을 열 수 없습니다. DMG 버전은 가능합니다.\n\nApp Store 버전은 이후 업데이트가 중단될 수 있습니다.';

  @override
  String get macDmgImportDenied => 'macOS가 이전 버전의 데이터를 읽도록 허용하지 않았습니다';

  @override
  String get macDmgImported => '이전 버전의 데이터를 가져왔습니다';

  @override
  String get macDmgImportFailed => '이전 버전의 데이터를 읽지 못했습니다';

  @override
  String get macDmgTip => '로컬 터미널과 로컬 snippet 실행 (DMG 버전)';

  @override
  String get macDmgTitle => 'DMG 버전';

  @override
  String get showHiddenFiles => '숨김 파일 표시';

  @override
  String get sshKeyAlgorithm => '알고리즘';

  @override
  String get sshKeyComment => '설명';

  @override
  String get sshKeyGenerate => '키 쌍 생성';

  @override
  String get sshKeyGenerating => '생성 중…';

  @override
  String sshKeyLockedFmt(String name) {
    return '개인 키 [$name]의 잠금이 해제되지 않았습니다.';
  }

  @override
  String get sshKeyPassphraseTip =>
      '선택 사항. 암호를 설정하면 개인 키가 암호화되어 저장되며, 연결에서 이 키를 처음 사용할 때 입력을 요구합니다.';

  @override
  String get sshKeyPassphraseWrong => '암호가 올바르지 않습니다.';

  @override
  String get sshKeyPublicKey => '공개 키';

  @override
  String get sshKeyPublicKeyTip => '이 줄을 서버의 ~/.ssh/authorized_keys에 추가하세요.';

  @override
  String get sshKeyRecommended => '권장';

  @override
  String sshKeyUnlockTip(String name) {
    return '개인 키 [$name]의 암호를 입력하세요.';
  }

  @override
  String get ungrouped => '그룹 없음';

  @override
  String get unused => '미사용';

  @override
  String get dangling => '댕글링';

  @override
  String get pruneUnusedImages => '미사용 이미지 정리';

  @override
  String get pruneDanglingImages => '댕글링 이미지 정리';

  @override
  String get pruneImages => '이미지 정리';

  @override
  String get unusedTaggedImages => '사용하지 않는 태그 이미지';

  @override
  String get pruneDanglingImagesTip => '댕글링 이미지만 제거합니다.';

  @override
  String get pruneUnusedImagesTip => '어떤 컨테이너에서도 사용하지 않는 태그 이미지도 제거합니다.';

  @override
  String get includeUnusedVolumesTip => '어떤 컨테이너에서도 사용하지 않는 볼륨도 제거합니다.';

  @override
  String get pruneCommandPreview => '명령 미리보기';

  @override
  String get pruneForceSshTip => '-f는 대화형 확인을 건너뛰며 SSH 실행에서 항상 활성화됩니다.';

  @override
  String get pruneVolumes => '볼륨 정리';

  @override
  String get pruneUnusedData => '사용하지 않는 데이터 정리';

  @override
  String get pull => '풀';

  @override
  String get invalidHostFormat => '잘못된 호스트 형식입니다. IPv4, IPv6, 도메인 문자만 허용됩니다.';

  @override
  String get jumpServer => '점프 서버';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return '$serverName에 대한 점프 서버를 찾을 수 없습니다: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
    return '\'$name\'은(는) 이미 존재합니다';
  }

  @override
  String get noJumpServerAvailable => '사용 가능한 점프 서버가 없습니다.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      '점프 서버와 ProxyCommand는 함께 사용할 수 없습니다.';

  @override
  String get keepForeground => '앱을 포그라운드에 유지해 주세요!';

  @override
  String get keepStatusWhenErr => '마지막 서버 상태 유지';

  @override
  String get keepStatusWhenErrTip => '스크립트 실행 중 오류가 발생한 경우에만';

  @override
  String get keyAuth => '키 인증';

  @override
  String get lastFailure => '마지막 실패';

  @override
  String get lastSuccess => '마지막 성공';

  @override
  String get letterCache => '일반 키보드 입력';

  @override
  String get letterCacheTip =>
      '이 옵션을 켜면 입력 내용이 일반 IME를 거치며, 일부 시스템에서는 터미널의 보안 키보드 안내를 피할 수 있습니다.';

  @override
  String get linuxShellTip => '터미널을 시작할 셸. 비우면 /bin/sh로 돌아갑니다.';

  @override
  String get linuxNetTip => 'DNS 서버. 비우면 기본값으로 돌아갑니다';

  @override
  String madeWithLove(Object myGithub) {
    return '$myGithub이(가) ❤️로 만들었습니다';
  }

  @override
  String get maxConcurrency => '최대 동시 실행 수';

  @override
  String get maxRetryCount => '서버 재연결 횟수';

  @override
  String mismatchSystem(Object system) {
    return '시스템이 일치하지 않습니다: $system';
  }

  @override
  String get mirror => '미러';

  @override
  String get needRestart => '앱을 다시 시작해야 합니다';

  @override
  String get netViewType => '네트워크 뷰 유형';

  @override
  String get newContainer => '새 컨테이너';

  @override
  String get noConnectionStatsData => '연결 통계 데이터가 없습니다';

  @override
  String get noLineChart => '꺾은선 그래프 사용 안 함';

  @override
  String get noPrivateKeyTip => '개인 키가 존재하지 않습니다. 삭제되었거나 설정 오류일 수 있습니다.';

  @override
  String get noPromptAgain => '다시 묻지 않기';

  @override
  String get onlyOneLine => '한 줄로만 표시 (스크롤 가능)';

  @override
  String get openLastPath => '마지막 경로 열기';

  @override
  String get openLastPathTip => '서버마다 다른 기록이 있으며, 기록은 종료 시의 경로입니다';

  @override
  String get parseContainerStatsTip => 'Docker 점유 상태 파싱이 비교적 느립니다.';

  @override
  String get plugInType => '삽입 유형';

  @override
  String get preferDiskAmount => '디스크 용량 우선 표시';

  @override
  String get privateKey => '개인 키';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return '개인 키 [$keyId]을(를) 찾을 수 없습니다.';
  }

  @override
  String get bmcPowerOnAction => '전원 켜기';

  @override
  String get bmcShutdown => '종료';

  @override
  String get bmcForceOff => '강제 종료';

  @override
  String get restart => '재시작';

  @override
  String get bmcPowerCycle => '전원 재투입';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return '$server에 실행할까요? 서비스에 \"$resetType\"을 보냅니다';
  }

  @override
  String get bmcPowerDone => '전원 상태가 바뀌었습니다';

  @override
  String get bmcPowerAccepted =>
      '접수되었지만 전원 상태는 아직 바뀌지 않았습니다. graceful 동작은 OS에 달려 있습니다';

  @override
  String get bmcPowerUnsupported => '이 서비스는 해당 작업에 대해 아무것도 허용하지 않습니다';

  @override
  String get bmcUnauthorized => 'BMC가 이 계정을 거부했습니다';

  @override
  String get bmcAccountMissing => '이 BMC에 계정이 설정되지 않았습니다';

  @override
  String get bmcPowerOn => '전원 켜짐';

  @override
  String get bmcPowerOff => '전원 꺼짐';

  @override
  String get bmcCertRejected => '인증서가 거부됨 — 서버 설정에서 확인하세요';

  @override
  String get bmcNotAService => '이 주소에는 Redfish 서비스가 없습니다';

  @override
  String get bmcNoSystem => '서비스가 시스템을 보고하지 않습니다';

  @override
  String get bmcSensorsTruncated => '앞쪽 센서만 표시됩니다';

  @override
  String get bmcMultipleSystems => '첫 번째 시스템만 표시됩니다';

  @override
  String get bmcTip =>
      'BMC는 메인보드에 있는 별도의 컴퓨터로, 호스트 OS가 응답하지 않아도 접근할 수 있습니다. 여기서 설정하면 서버가 꺼져 있거나 멈춰 있어도 전원 상태와 하드웨어 센서를 읽을 수 있습니다. Redfish가 필요하며 대략 2016년 이후 기업용 하드웨어는 대부분 지원합니다.';

  @override
  String get bmcCert => '인증서';

  @override
  String get bmcCertPinned => '확인 후 고정됨';

  @override
  String get bmcCertUnreviewed => '아직 확인하지 않음 — 눌러서 인증서 보기';

  @override
  String get bmcCertReview => '자체 서명 인증서입니다. 수락하기 전에 대조하세요. 이후에는 이 인증서만 신뢰합니다.';

  @override
  String get bmcCertChanged => '인증서가 일치하지 않습니다. 확인하세요.';

  @override
  String get bmcCertExpired => '만료되었습니다.';

  @override
  String bmcCertWas(String fingerprint) {
    return '이전에 수락함: $fingerprint';
  }

  @override
  String get bmcAddrInvalid => 'BMC 주소는 URL이어야 합니다. 예: https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      '이 빌드는 샌드박스에서 실행됩니다: 명령이 받는 home은 비어 있어 당신 것이 아니며, ~/.ssh를 읽는 것은 모두 실패합니다. DMG 버전은 아닙니다.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return '개인 키 파일 $path을(를) 읽을 수 없습니다: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return '이 빌드는 컨테이너 밖의 파일을 읽을 수 없어 $path의 키에 접근할 수 없습니다. 설정에서 키를 가져오거나 DMG 버전을 사용하세요.';
  }

  @override
  String get pushToken => '푸시 토큰';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand는 데스크톱 플랫폼에서만 지원됩니다.';

  @override
  String get pveIgnoreCertTip =>
      '활성화를 권장하지 않습니다. 보안 위험에 주의하세요! PVE 기본 인증서를 사용하는 경우 이 옵션을 활성화해야 합니다.';

  @override
  String get pveServerClientMissing => '이 서버의 SSH 클라이언트를 사용할 수 없습니다.';

  @override
  String get pveAddressMissing => 'PVE 주소가 없습니다. 서버 설정에서 구성해 주세요.';

  @override
  String get pvePasswordRequired => 'PVE 비밀번호가 필요합니다. 서버 설정에서 설정해 주세요.';

  @override
  String get pveOtpRequired =>
      '이 PVE 서버에는 2단계 인증이 활성화되어 있습니다. OTP 코드를 입력해 주세요.';

  @override
  String get pveOtpChallengeExpired => 'OTP 인증 요청이 만료되었습니다. 새로고침 후 다시 시도해 주세요.';

  @override
  String get pveOtpCodeRequired => 'OTP 코드가 필요합니다.';

  @override
  String get pveOtpVerificationFailed => 'OTP 인증에 실패했습니다. 새 코드로 다시 시도해 주세요.';

  @override
  String get pveOtpTitle => 'OTP 인증';

  @override
  String get pveOtpLabel => 'OTP 코드';

  @override
  String get pveInvalidResponseBody => 'PVE 로그인이 잘못된 응답 본문을 반환했습니다.';

  @override
  String get pveInvalidResponseData => 'PVE 로그인 응답에 유효한 데이터가 포함되어 있지 않습니다.';

  @override
  String get pveMissingAuthTicket => 'PVE 로그인은 성공했지만 인증 티켓이 반환되지 않았습니다.';

  @override
  String get pveVersionLow =>
      '이 기능은 현재 테스트 단계이며 PVE 8+에서만 테스트되었습니다. 주의하여 사용해 주세요.';

  @override
  String get pveLoadingForwarding => 'SSH 터널을 설정하는 중...';

  @override
  String get pveLoadingLogin => 'PVE에 인증하는 중...';

  @override
  String get pveLoadingData => '클러스터 데이터를 가져오는 중...';

  @override
  String get pveLoadingConnect => '연결하는 중...';

  @override
  String get pvePassword => 'PVE 비밀번호';

  @override
  String get pvePasswordHint => '키 기반 SSH 인증을 사용할 때 필요합니다';

  @override
  String get read => '읽기';

  @override
  String get recentConnections => '최근 연결';

  @override
  String get rememberPwdInMem => '메모리에 비밀번호 저장';

  @override
  String get rememberPwdInMemTip => '컨테이너, 일시 중지 등에 사용됩니다.';

  @override
  String get remotePath => '원격 경로';

  @override
  String rootfsUpdateTip(
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return '$distro $installed이(가) 설치되어 있고 $latest가 있습니다. 업데이트는 컨테이너 전체를 교체합니다: $pm 데이터가 사라집니다';
  }

  @override
  String linuxSystemInUse(Object name) {
    return '$name의 터미널을 닫은 뒤 삭제하세요';
  }

  @override
  String get rootfsSubtitle => '이 기기의 Linux 사용자 공간';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
    return '$distro $version(약 $size MB)을 내려받아 이 기기에 풉니다.';
  }

  @override
  String get sameIdServerExist => '동일한 ID의 서버가 이미 존재합니다';

  @override
  String get second => '초';

  @override
  String get serverFilesUnavailableTip =>
      '이 서버에 대한 SSH가 필요하거나, server_box_monitor를 설치하고 파일 API를 켜야 합니다.';

  @override
  String get back => '뒤로';

  @override
  String get history => '기록';

  @override
  String get homeDir => '홈';

  @override
  String selected(Object count) {
    return '$count개 선택됨';
  }

  @override
  String get sendTo => '보낼 위치…';

  @override
  String get serverDetailOrder => '상세 페이지 위젯 순서';

  @override
  String get serverFuncBtns => '서버 기능 버튼';

  @override
  String get serverOrder => '서버 순서';

  @override
  String get serverTabRequired => '서버 탭은 제거할 수 없습니다';

  @override
  String get shareServerRiskTip =>
      '이 QR 코드는 서버 접속 설정을 평문으로 담고 있습니다. 스캔하거나 촬영한 사람은 누구나 접속할 수 있습니다.';

  @override
  String get sftpDlPrepare => '연결 준비 중...';

  @override
  String get sftpEditorTip =>
      '비우면 내장 편집기를 씁니다. 예를 들어 `vim`(`EDITOR`에서 읽는 것을 권장).';

  @override
  String get sftpRmrDirSummary => 'SFTP에서 `rm -r`을 사용하여 폴더를 삭제합니다.';

  @override
  String get sftpSSHConnected => 'SFTP 연결됨';

  @override
  String get sftpShowFoldersFirst => '폴더 우선 표시';

  @override
  String get specifyDev => '장치 지정';

  @override
  String get specifyDevTip => '네트워크 트래픽은 기본적으로 모든 장치를 합칩니다. 여기서 지정할 수 있습니다';

  @override
  String get tempIsCelsiusTip =>
      '활성화하면 온도 값이 밀리섭씨가 아닌 섭씨로 처리됩니다. 온도가 잘못 표시될 때만 켜세요 (예: 58°C 대신 0.1°C로 표시되는 경우).';

  @override
  String spentTime(Object time) {
    return '소요 시간: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return '모든 서버가 이미 존재합니다 (중복 $duplicateCount개 발견)';
  }

  @override
  String get sshConnectionModeTip =>
      '내장: 앱의 터미널을 사용합니다. 시스템 SSH: 외부 터미널에서 시스템 ssh 명령을 실행합니다.';

  @override
  String get sshConnectionModeUseBuiltin => '내장 터미널 사용';

  @override
  String get sshConnectionModeUseSystem => '시스템 SSH 사용';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '중복 $duplicateCount개가 건너뛰어집니다';
  }

  @override
  String get sshConfigFound => '시스템에서 SSH 설정을 발견했습니다.';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return '서버 $totalCount개를 발견했습니다';
  }

  @override
  String get sshConfigImport => 'SSH 설정 가져오기';

  @override
  String get sshConfigImportPermission =>
      '~/.ssh/config를 읽고 서버 설정을 자동으로 가져올 수 있는 권한을 부여하시겠습니까?';

  @override
  String get sshConfigImportTip => '첫 서버 생성 시 ~/.ssh/config 읽기 안내';

  @override
  String sshConfigImported(Object count) {
    return 'SSH 설정에서 서버 $count개를 가져왔습니다';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return '$serverName의 SSH 호스트 키가 변경되었습니다. 이 서버를 신뢰하는 경우에만 계속 진행하세요.';
  }

  @override
  String get sshHostKeyType => 'SSH 호스트 키 유형';

  @override
  String get sshKnownHostKeys => '알려진 호스트';

  @override
  String get sshKnownHostKeysTip => '이 앱이 수락한 호스트 키';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return '$serverName에서 새 SSH 호스트 키를 수신했습니다. 신뢰하기 전에 지문을 확인해 주세요.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
    return '저장된 지문: $fingerprint';
  }

  @override
  String get sshVerificationCode => '인증 코드';

  @override
  String get sshConfigManualSelect => 'SSH 설정 파일을 수동으로 선택하시겠습니까?';

  @override
  String get sshConfigNoServers => 'SSH 설정에서 서버를 찾을 수 없습니다';

  @override
  String get sshConfigPermissionDenied =>
      'macOS 권한으로 인해 SSH 설정 파일에 접근할 수 없습니다.';

  @override
  String sshConfigServersToImport(Object importCount) {
    return '서버 $importCount개가 가져오기됩니다';
  }

  @override
  String get sshTermHelp =>
      '터미널이 스크롤 가능할 때, 가로로 드래그하면 텍스트를 선택할 수 있습니다. 키보드 버튼을 누르면 키보드가 켜지거나 꺼집니다. 파일 아이콘은 현재 경로를 SFTP로 엽니다. 클립보드 버튼은 텍스트가 선택되어 있을 때 내용을 복사하고, 텍스트가 선택되어 있지 않고 클립보드에 내용이 있을 때 터미널에 붙여넣습니다. 코드 아이콘은 코드 스니펫을 터미널에 붙여넣고 실행합니다.';

  @override
  String get sshVirtualKeyAutoOff => '가상 키 자동 전환';

  @override
  String get supportFmtArgs => '다음 형식 매개변수가 지원됩니다:';

  @override
  String get suspendTip => '일시 중지 기능은 root 권한과 systemd 지원이 필요합니다.';

  @override
  String switchTo(Object val) {
    return '$val(으)로 전환';
  }

  @override
  String get syncAppSettings => '앱 설정 동기화';

  @override
  String get syncAppSettingsTip =>
      '자동 동기화에 테마, 레이아웃, 편집기, 터미널 등 기타 기기 환경설정을 포함합니다.';

  @override
  String get termFontSizeTip =>
      '이 설정은 터미널 크기(너비 및 높이)에 영향을 줍니다. 현재 세션의 글꼴 크기를 조정하려면 터미널 페이지에서 확대/축소할 수 있습니다.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (원래 크기), 서버 페이지의 일부 글꼴에만 적용되며 변경을 권장하지 않습니다.';

  @override
  String get times => '회';

  @override
  String get trySudo => 'sudo 사용 시도';

  @override
  String get sudoPromptNotFound => 'sudo 비밀번호 프롬프트가 없습니다.';

  @override
  String get updateServerStatusInterval => '서버 상태 업데이트 간격';

  @override
  String get useNoPwd => '비밀번호를 사용하지 않습니다';

  @override
  String get usePodmanByDefault => '기본적으로 Podman 사용';

  @override
  String get used => '사용됨';

  @override
  String get view => '보기';

  @override
  String get viewDetails => '상세 보기';

  @override
  String get virtKeyHelpClipboard =>
      '터미널에 선택된 텍스트가 있으면 클립보드에 복사하고, 없으면 클립보드 내용을 터미널에 붙여넣습니다.';

  @override
  String get virtKeyHelpIME => '키보드 켜기/끄기';

  @override
  String get virtKeyHelpSFTP => '현재 디렉토리를 SFTP로 열기.';

  @override
  String get virtKeyHelpSnippet => '스니펫을 골라 이 터미널에서 실행합니다.';

  @override
  String get virtKeyHelpTmux => 'tmux 세션과 창을 전환합니다.';

  @override
  String get virtKeyIntroActions => '바로가기';

  @override
  String get virtKeyIntroActionsTip =>
      '이 키들은 문자를 입력하지 않고 기능을 엽니다. 길게 누르면 설명을 볼 수 있습니다.';

  @override
  String get virtKeyIntroCustomizeTip =>
      '터미널 설정에서 순서를 바꾸거나, 쓰지 않는 키를 숨길 수 있습니다.';

  @override
  String get virtKeyIntroModifiers => '조합 키';

  @override
  String get virtKeyIntroModifiersTip =>
      '한 번 눌러 켠 다음 키보드의 글자를 누르세요. 바로 다음 한 키에만 적용됩니다.';

  @override
  String get virtKeyIntroNav => '커서 이동';

  @override
  String get virtKeyIntroNavTip => '이 키들은 커서를 옮깁니다. 방향키를 길게 누르면 반복됩니다.';

  @override
  String get virtKeyIntroSelect => '터미널에 스크롤할 내용이 있으면 가로로 끌어 텍스트를 선택할 수 있습니다.';

  @override
  String get waitConnection => '연결이 설정될 때까지 기다려 주세요.';

  @override
  String get wakeLock => '화면 깨우기 유지';

  @override
  String get watchNotPaired => '페어링된 Apple Watch가 없습니다';

  @override
  String get webdavSettingEmpty => 'WebDav 설정이 비어 있습니다';

  @override
  String get whenOpenApp => '앱을 열 때';

  @override
  String get wolTip => 'WOL (Wake-on-LAN)을 설정하면 서버에 연결할 때마다 WOL 요청이 전송됩니다.';

  @override
  String get write => '쓰기';

  @override
  String get writeScriptFailTip =>
      '스크립트 작성에 실패했습니다. 권한이 부족하거나 디렉토리가 존재하지 않을 수 있습니다.';

  @override
  String get writeScriptTip =>
      '서버 연결 후 시스템 상태를 모니터링하기 위한 스크립트가 `~/.config/server_box` \n | `/tmp/server_box`에 작성됩니다. 스크립트 내용을 확인할 수 있습니다.';

  @override
  String get menuGitHubRepository => 'GitHub 저장소';

  @override
  String get podmanDockerEmulationDetected =>
      'Podman Docker 에뮬레이션이 감지되었습니다. 설정에서 Podman으로 전환해 주세요.';

  @override
  String get betaTip => '이 기능은 아직 베타 테스트 중입니다. 정상 동작이 보장되지 않습니다.';

  @override
  String get portForward_startPrompt => '포트 포워딩 규칙을 추가하여 시작하세요';

  @override
  String get portForward_localHost => '로컬 호스트';

  @override
  String get portForward_localPort => '로컬 포트';

  @override
  String get portForward_remoteHost => '원격 호스트';

  @override
  String get portForward_remotePort => '원격 포트';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return '$name을(를) 삭제하시겠습니까?';
  }

  @override
  String get sponsor => '후원';

  @override
  String get sortByJoinTime => '가입 시간순';

  @override
  String get serverHistory => '서버 기록';

  @override
  String get portForwardBetaTitle => '포트 포워딩 (Beta)';

  @override
  String get tmuxAutoAttach => 'tmux 자동 연결';

  @override
  String get tmuxAuto => '자동 tmux';

  @override
  String get tmuxAutoTip => 'SSH로 접속할 때 tmux를 자동으로 시작하거나 연결합니다';

  @override
  String get tmuxSessionSelector => '세션 선택기';

  @override
  String get tmuxSessionSelectorTip => '접속할 때 세션 선택기를 표시합니다';

  @override
  String get tmuxDefaultSessionName => '기본 세션 이름';

  @override
  String get tmuxSessionName => '세션 이름';

  @override
  String get tmuxExistingSessions => '기존 세션';

  @override
  String get tmuxNewSession => '새 세션';

  @override
  String get tmuxWindows => '창';

  @override
  String get tmuxNewWindow => '새 창';

  @override
  String get tmuxNoWindowsFound => '창을 찾을 수 없습니다';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '창 $count개',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '페인 $count개',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => '연결됨';

  @override
  String get tmuxActive => '활성';

  @override
  String tmuxActiveAt(String time) {
    return '활성: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return '연결: $time';
  }

  @override
  String get tmuxSkip => '건너뛰기';

  @override
  String get tmuxNotAvailable => 'tmux를 사용할 수 없습니다';

  @override
  String containerSegmentsMismatch(int count) {
    return '컨테이너 응답 세그먼트 수가 예상과 다릅니다: $count';
  }

  @override
  String get containerOperationInProgress => '다른 컨테이너 작업이 이미 진행 중입니다';

  @override
  String processCount(int count) {
    return '프로세스 $count개';
  }

  @override
  String get processParseUnsupportedOutput => '이 프로세스 목록 형식은 지원되지 않습니다.';

  @override
  String get processParseInvalidRows => '일부 프로세스 항목을 읽을 수 없습니다.';

  @override
  String get processParseInvalidWindowsJson => 'Windows 프로세스 응답을 읽을 수 없습니다.';

  @override
  String get processParseInvalidWindowsRows => '일부 Windows 프로세스 항목을 읽을 수 없습니다.';

  @override
  String get processKillTargetChanged =>
      '프로세스가 변경되었거나 종료되었습니다. 목록을 새로 고친 후 다시 시도하세요.';

  @override
  String get watchServers => '워치에 표시할 서버';

  @override
  String get watchServersTip =>
      '시계는 스스로 monitor에서 가져오므로 monitor가 있는 서버만 고를 수 있습니다.';

  @override
  String get watchNoMonitorServer => 'monitor 에이전트가 설정된 서버가 없습니다';

  @override
  String get watchLegacyUrls => '레거시 status URL';

  @override
  String get accessoryWidgetServer => '잠금 화면 위젯 서버';

  @override
  String get systemdMissing => '이 서버에는 systemd가 없습니다';

  @override
  String get systemdMissingTip => '`systemctl`이 설치되어 있지 않아 나열할 unit이 없습니다.';

  @override
  String initSystemFmt(String init) {
    return '이 머신은 $init을(를) 사용하는 것으로 보입니다.';
  }

  @override
  String get systemdListFailed => 'unit을 나열할 수 없습니다';

  @override
  String get systemdUserScopeMissing => '사용자 unit이 나열되지 않았습니다';

  @override
  String get systemdUserScopeMissingTip =>
      '이 계정에는 서버에 사용자 세션 버스가 없어 시스템 unit만 표시됩니다.';

  @override
  String get serverUnreachable => '이 서버에서 명령을 실행할 수 없습니다';

  @override
  String get containerNoRuntime => '컨테이너 런타임이 없습니다';

  @override
  String get containerNoRuntimeTip =>
      '이 머신에서 `docker`와 `podman` 모두 응답하지 않았습니다. 다른 계정에 설치되어 있다면 설정에서 \"sudo 사용 시도\"를 켜세요.';

  @override
  String get containerUnreadable => '컨테이너 런타임이 예상과 다른 형식으로 응답했습니다';

  @override
  String get power => '전원';

  @override
  String get continueInTerminal => '터미널에서 계속하기';

  @override
  String get askAiRiskUnknown => '분류되지 않음';

  @override
  String get agentLocalExec => '이 기기에서 명령 실행';

  @override
  String get agentLocalExecTip =>
      'ServerBox가 실행 중인 이 기기에서 Agent가 작업하게 합니다. 읽기 전용 명령도 검토가 필요합니다';

  @override
  String get agentLocalExecRootfsTip =>
      'Agent를 로컬에서 동작하게 하며, 범위는 ServerBox가 설치한 Linux 컨테이너 안으로 제한됩니다';

  @override
  String macDmgImportedPartly(String path) {
    return '이전에 설치된 빌드의 데이터를 가져왔습니다. 다운로드한 파일은 $path에 그대로 있습니다.';
  }

  @override
  String get bmcAccount => '계정';

  @override
  String get bmcAccountUnset => '선택되지 않음 — 탭하여 선택하거나 새로 만들기';

  @override
  String bmcAccountShared(int count) {
    return '$count대의 서버에서 사용 중';
  }

  @override
  String get bmcAccounts => 'BMC 계정';

  @override
  String get bmcAccountSharedTip => '여기서 수정하면 모두에게 적용됩니다.';

  @override
  String bmcAccountInUse(int count) {
    return '$count대의 서버가 사용 중입니다. 주소는 남고 계정은 사라집니다.';
  }

  @override
  String get bmcStaleWrite => '쓰는 동안 BMC가 변경되었습니다. 다시 시도하세요.';

  @override
  String get send => '보내기';
}
