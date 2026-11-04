import type { Translation } from '../i18n-types.js'

const kr: Translation = {
  meta: {
    lang: 'ko',
    title: 'ServerBox — 서버 모니터링, SSH, 운영을 하나로 담은 네이티브 앱',
    description:
      '실시간 차트, 터치 최적화 SSH 터미널, SFTP, Docker, systemd, S.M.A.R.T., 위젯, AI 에이전트로 Linux, Unix, Windows 서버를 어디서나 관리하세요.',
  },
  nav: {
    features: '기능',
    capabilities: '도구',
    download: '다운로드',
    docs: '문서',
    themes: '테마',
    os: 'ServerBox OS',
    beta: '베타',
    plugins: '플러그인',
    otherApps: '더보기',
    signIn: '로그인',
    languageLabel: '언어',
  },
  hero: {
    titlePrefix: '모든 서버를,',
    titleSuffix: '내 손안에.',
    subtitle:
      '실시간 지표, 터치에 최적화된 SSH 터미널, SFTP, 컨테이너 관리와 AI 운영 에이전트를 빠르고 가벼운 네이티브 워크스페이스 하나에 담았습니다.',
    primaryAction: '다운로드',
    secondaryAction: '기능 살펴보기',
  },
  screenshots: {
    label: 'ServerBox 인터랙티브 스크린샷',
    one: 'ServerBox 서버 개요 스크린샷',
    two: 'ServerBox 상태 차트 스크린샷',
    three: 'ServerBox 터미널 스크린샷',
    four: 'ServerBox 파일 브라우저 스크린샷',
  },
  features: {
    title: '실전 서버 운영을 위한 설계.',
    subtitle:
      '일상 점검부터 긴급 장애 대응까지, 노트북을 열지 않고도 즉시 해결하세요.',
    list: {
      title: '한눈에 보는 서버 현황',
      description:
        '모든 노드의 연결 상태와 CPU, 메모리, 디스크, 네트워크 부하를 즉시 파악하세요. 태그 필터링과 3D 지구본 뷰를 지원합니다.',
    },
    charts: {
      title: '실시간 및 이력 차트',
      description:
        'CPU, 메모리, 스왑, 디스크 I/O, 네트워크는 물론 GPU, 센서, S.M.A.R.T. 상태까지 실시간과 기록 차트로 세밀하게 추적합니다.',
    },
    terminal: {
      title: 'SSH 터미널',
      description:
        '모바일 가상 키로 vim, tmux, htop을 쾌적하게 조작하세요. 점프 호스트와 ProxyCommand를 기본 지원합니다.',
    },
    files: {
      title: 'SFTP 파일 관리',
      description:
        '원격 파일을 탐색·전송하고 그 자리에서 바로 편집하세요. Markdown 파일은 깔끔한 렌더링 미리보기로 열립니다.',
    },
    containers: {
      title: 'Docker & Podman',
      description:
        'Compose 프로젝트별로 컨테이너를 묶어 리소스를 확인하고, 원탭 재시작, 실시간 로그 확인, 컨테이너 내부 셸 접속을 수행합니다.',
    },
    processes: {
      title: '프로세스 진단',
      description:
        'CPU·메모리 사용량 정렬과 이름·사용자·PID 검색으로 비정상 프로세스를 찾아 즉시 종료합니다.',
    },
    services: {
      title: 'Systemd 서비스',
      description:
        '실패한 systemd 유닛을 목록 최상단에 자동 고정합니다. 한 번의 탭으로 재시작하거나 저널 로그를 확인하세요.',
    },
    users: {
      title: '계정 및 권한 관리',
      description:
        '시스템 계정, 로그인 셸, sudo 권한을 한눈에 점검하고 복잡한 명령어 없이 사용자와 그룹을 관리합니다.',
    },
    agent: {
      title: 'AI 운영 에이전트',
      description:
        '원하는 LLM 제공자, MCP 서버, 스킬을 연결해 로그 분석과 일상 유지보수를 AI 어시스턴트에게 맡기세요.',
    },
    bench: {
      title: '원탭 벤치마크',
      description:
        'YABS로 디스크·네트워크·CPU 성능을 측정해 기록을 보관하고, 스니펫·원격 데스크톱·가상화 도구로 바로 이동합니다.',
    },
    virt: {
      title: '가상화 제어',
      description:
        'Proxmox VE와 libvirt의 VM 및 컨테이너를 제어하세요. 전원 관리, vCPU·메모리·디스크 조정, 콘솔 연결을 지원합니다.',
    },
    themes: {
      title: '테마 스토어',
      description:
        '공식 테마의 색상, 배경, 아이콘, 스플래시 화면을 앱 안에서 바로 적용하거나 나만의 테마를 직접 제작하세요.',
    },
  },
  capabilities: {
    title: '모든 도구를 하나의 흐름으로.',
    subtitle:
      '터미널, SFTP 클라이언트, 모니터링 대시보드를 따로 오갈 필요가 없습니다.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux, Windows',
  },
  os: {
    metaTitle: 'ServerBox OS (구 ServerBox Monitor) — 브라우저 데스크톱과 서버 모니터링 엔진',
    metaDescription:
      'ServerBox OS (구 ServerBox Monitor)는 브라우저 데스크톱, 40개 이상의 원클릭 Docker 앱, ZFS/RAID 스토리지, AI 에이전트, 알림, 암호화 백업을 서버에 제공합니다.',
    heroTitle: 'ServerBox OS',
    formerlyMonitor: '구 ServerBox Monitor',
    navPreview: '데모',
    navInstall: '설치',
    navApp: 'ServerBox 앱',
    tagline: '브라우저에서도, 앱에서도 완벽한 서버 파트너.',
    subtitle:
      '가벼운 단일 프로그램 하나로 Linux 서버에 브라우저 멀티윈도우 데스크톱, 40개 이상의 셀프호스팅 앱, AI 에이전트, 그리고 ServerBox 앱과의 HTTPS 연동을 제공합니다.',
    monitorNote:
      'ServerBox OS는 기존 ServerBox Monitor(server_box_monitor)의 업그레이드 버전입니다. 기존 Monitor 설치 환경도 동일한 명령어로 제자리 업그레이드되며, 푸시 알림·홈 위젯·watchOS·이력 차트를 그대로 지원합니다.',
    exploreAction: 'ServerBox OS 자세히 보기',
    installAction: 'Linux에 설치',
    images: 'OS 이미지 다운로드',
    previewAction: '데모 보기',
    previewTitle: '실제 작동 모습',
    previewSubtitle:
      '실제 서버 데모: 브라우저 속 데스크톱, 원클릭 앱 배포, AI Agent 모드의 자율 작업.',
    previewPlay: 'ServerBox OS 데모 재생',
    previewYoutube: 'YouTube에서 보기',
    featuresTitle: '서버에서 실행되는 모든 기능',
    featuresSubtitle: '호스트의 단일 바이너리에 브라우저나 모바일 앱으로 언제든 접속하세요.',
    desk: {
      title: '브라우저 속 데스크톱',
      description:
        '서버 주소를 열면 상태, 파일, 터미널, 컨테이너, 프로세스, 서비스가 각각 독립된 창으로 실행됩니다.',
    },
    apps: {
      title: '원클릭 앱 스토어',
      description:
        'Immich, Jellyfin, Gitea, Home Assistant 등 40개 이상의 Docker Compose 서비스와 Tailscale, 리버스 프록시, 로컬 AI 모델을 손쉽게 배포하세요.',
    },
    storage: {
      title: '스토리지 & NAS 공유',
      description:
        '디스크 파티션·마운트, RAID 및 ZFS 풀 구성, S.M.A.R.T. 점검, SMB/NFS 폴더 공유를 웹에서 처리합니다.',
    },
    agent: {
      title: '자율 Agent 모드',
      description:
        'AI 에이전트가 계획을 세우고 위험한 명령 전 승인을 요청하며, 허용 시에만 sudo를 사용하고 MCP로 배포된 앱과 소통합니다.',
    },
    alerts: {
      title: '멀티채널 알림',
      description:
        'CPU, 메모리, 디스크, 서비스 이상 시 앱, Telegram, Discord, ntfy, Bark, ServerChan, 이메일, 웹훅으로 즉시 알립니다.',
    },
    backups: {
      title: '암호화 백업',
      description:
        '설정은 age로 암호화해 WebDAV에 백업하고, 컨테이너 데이터는 지정한 디스크에 스케줄에 맞춰 자동 백업합니다.',
    },
    security: {
      title: '안전한 인증과 감사',
      description:
        '읽기 외 모든 작업에 HTTPS를 강제하고 자격 증명을 암호화 저장하며, 로그인과 root 작업을 감사 로그에 기록합니다.',
    },
    app: {
      title: '모바일 앱 완벽 연동',
      description:
        'SSH 대신 또는 함께 HTTPS로 연결해 이력 차트, 푸시 알림, 위젯, Agent 작업과 웹 앱을 휴대폰에서 바로 이용하세요.',
    },
    installTitle: '두 가지 설치 방법',
    installSubtitle: '기존 Linux 서버에 한 줄 명령어로 설치하거나 전용 OS 이미지로 부팅하세요.',
    linuxTitle: '기존 Linux 서버에 설치',
    promptUser: '# systemd: 본인 계정 권한으로 실행되는 사용자 서비스',
    promptOpenrc: '# OpenRC (Alpine): root가 등록하고 본인 계정으로 실행',
    promptRoot: '# systemd 또는 OpenRC: root 권한 시스템 서비스',
    linuxNote:
      '실행 계정의 권한을 그대로 따릅니다. install을 upgrade나 uninstall로 바꾸면 업데이트·삭제됩니다.',
    copy: '설치 명령 복사',
    imageTitle: '전용 시스템으로 부팅',
    stepWrite: '이미지를 USB(dd, Etcher, Ventoy)에 구워 부팅하거나 가상 머신에 마운트하세요.',
    stepBoot:
      '부팅 후 콘솔에 표시되는 접속 주소, TLS 인증서 지문, 초기 비밀번호 위치를 확인합니다.',
    stepInstall: 'sbm-install <디스크> 명령으로 대상 디스크에 영구 설치합니다.',
    liveNote:
      '디스크 설치 전에는 메모리 Live 모드로 동작하며 재부팅 시 초기화됩니다.',
    note: 'ServerBox OS는 앱과 동일하게 AGPLv3 오픈소스입니다.',
    docs: 'Monitor 문서',
    appAction: '앱 다운로드',
  },
  themes: {
    title: '나만의 스타일로.',
    subtitle:
      '공식 테마를 아래에서 실시간으로 미리 보세요. 앱의 설정 → 모양 → 테마 스토어에서 바로 설치하거나 .fsbt 파일을 가져올 수 있습니다.',
    empty:
      '아직 공식 테마가 없습니다. 가이드를 참고해 테마를 제작하고 스토어에 등록해 보세요.',
    note: '모든 스토어 패키지는 설치 전 SHA-256 체크섬을 검증합니다.',
    authoring: '테마 제작 가이드',
    download: '.fsbt 다운로드',
    source: '소스 코드',
    light: '라이트',
    dark: '다크',
    search: '테마 및 아이콘 팩 검색',
    modeLabel: '모드',
    all: '전체',
    sortLabel: '정렬',
    sortName: '이름순',
    sortUpdated: '최신순',
    noMatch: '일치하는 테마가 없습니다. 다른 검색어나 모드를 선택해 보세요.',
    storeTitle: '테마 스토어',
    storeSubtitle:
      '공식 테마와 아이콘 팩의 실제 색상, 컴포넌트, 아이콘, 스플래시 화면을 웹에서 그대로 미리 보세요.',
    browse: '테마 스토어 열기',
    back: '모든 테마',
    details: '상세 보기',
    icons: '아이콘',
    tabIcons: '탭 바 및 활성 상태',
    navIcons: '내비게이션 기호',
    palette: '컬러 팔레트',
    components: '컴포넌트',
    splash: '스플래시 화면',
    install: '설치 방법',
    installSteps:
      '앱의 “설정 → 모양 → 테마 스토어”에서 {name}을(를) 선택하거나, .fsbt 파일을 받아 “테마 설치 → 파일”로 불러오세요.',
    base: '기본',
    hovered: '호버',
    pressed: '누름',
    disabled: '비활성',
    loadFailed: '테마 미리보기를 불러오지 못했습니다.',
    retry: '다시 시도',
    iconPacks: '아이콘 팩',
    iconPacksSubtitle:
      '아이콘 팩은 어떤 테마와도 자유롭게 조합할 수 있습니다. “설정 → 모양 → 테마 스토어 → 아이콘 팩”에서 적용하세요.',
  },
  plugins: {
    title: 'ServerBox 확장',
    subtitle: '공식 플러그인으로 필요한 기능을 더하세요.',
    empty: '아직 공식 플러그인이 없습니다.',
    download: '다운로드',
  },
  download: {
    title: '모든 플랫폼 네이티브 지원.',
    subtitle:
      '사용 중인 운영체제와 선호하는 설치 경로를 선택하세요.',
    copied: '설치 명령 복사됨',
    copyPrompt: '설치 명령을 복사하세요:',
    note:
      '팁: 서버에 ServerBox OS를 함께 설치하면 푸시 알림, 홈 위젯, 이력 차트를 사용할 수 있습니다.',
  },
  cta: {
    title: 'AGPLv3 기반 무료 오픈소스.',
    subtitle:
      'GitHub에서 코드를 확인하고 기여하거나 지금 바로 최신 버전을 다운로드하세요.',
    appStoreAction: 'App Store',
    githubAction: 'GitHub Releases',
  },
  pride: {
    badge: 'LGBTQ+ 프렌들리',
    title: '다양성과 자긍심을 담아.',
    description:
      'ServerBox는 LGBTQ+ 커뮤니티를 자랑스럽게 지지합니다. 테마 스토어에서 Rainbow, Trans, Nonbinary 3가지 변형을 담은 공식 Pride 테마를 만나보세요.',
    rainbow: 'Rainbow',
    trans: 'Trans',
    nonbinary: 'Nonbinary',
  },
  otherApps: {
    title: '더 많은 서비스와 앱.',
    subtitle:
      '빠른 반응성과 깔끔한 설계 철학을 공유하는 클라우드 서비스 및 네이티브 앱입니다.',
    servicesHeading: '서비스',
    appsHeading: 'Apps',
    llmapi: {
      title: 'LLM API',
      description:
        '주요 프런티어 LLM을 하나로 묶은 통합 API 게이트웨이로, ServerBox AI 에이전트와 GPT Box 및 개발 도구에 바로 연결됩니다.',
    },
    uptimer: {
      title: 'Uptimer',
      description:
        '웹사이트, API, 서버의 가동 상태를 모니터링하고 상태 페이지와 즉각적인 장애 알림을 제공하는 경량 서비스입니다.',
    },
    gptbox: {
      title: 'GPT Box',
      tag: 'iOS · Android · macOS · Linux · Windows',
      description:
        'OpenAI 및 호환 LLM API를 위한 빠르고 가벼운 네이티브 클라이언트로, 로컬 대화 보관, 도구 호출, 커스텀 엔드포인트를 지원합니다.',
      action: 'GitHub',
    },
    mfuse: {
      title: 'MFuse',
      tag: 'macOS · File Provider',
      description:
        '커널 확장 없이 macOS 네이티브 File Provider를 통해 SFTP, S3, WebDAV 등 원격 스토리지를 Finder에 바로 마운트합니다.',
      action: 'mfuse.lollipopkit.com',
    },
  },
  footer: {
    features: '기능',
    capabilities: '도구',
    releases: '릴리스',
  },
}

export default kr
