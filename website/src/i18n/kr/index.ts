import type { Translation } from '../i18n-types.js'

const kr: Translation = {
  meta: {
    lang: 'ko',
    title: 'ServerBox — 서버 상태, SSH, 운영 도구를 하나의 Flutter 앱으로',
    description:
      'ServerBox는 상태 차트, SSH 터미널, SFTP, Docker, 프로세스, systemd, S.M.A.R.T, 푸시, 위젯, watchOS로 Linux, Unix, Windows 서버를 모니터링합니다.',
  },
  nav: {
    features: '기능',
    capabilities: '도구',
    download: '다운로드',
    docs: '문서',
    themes: '테마',
    plugins: '플러그인',
    monitor: 'Monitor',
    languageLabel: '언어',
  },
  hero: {
    titlePrefix: '서버 상태를,',
    titleSuffix: '손안에서 확인하세요.',
    subtitle:
      'ServerBox는 차트, SSH 터미널, SFTP, Docker, 프로세스 제어, systemd, S.M.A.R.T, 푸시 알림, 위젯, watchOS 지원을 하나의 Flutter 앱에 담았습니다.',
    primaryAction: 'ServerBox 다운로드',
    secondaryAction: '기능 보기',
  },
  screenshots: {
    label: 'ServerBox 인터랙티브 스크린샷',
    one: 'ServerBox 서버 개요 스크린샷',
    two: 'ServerBox 상태 차트 스크린샷',
    three: 'ServerBox 터미널 스크린샷',
    four: 'ServerBox 파일 브라우저 스크린샷',
  },
  gallery: {
    title: '모든 화면을, 모든 기기에서.',
    subtitle:
      'iPhone, iPad, macOS의 스크린샷 31장. 페이지를 가볍게 유지하기 위해 열기 전에는 불러오지 않습니다.',
    count: '{count}장',
  },
  features: {
    title: '일상적인 서버 관리를 위한 컴팩트한 작업 공간.',
    subtitle:
      '장식 없이 실제 운영 흐름에 맞춘 밀도 높은 인터페이스입니다.',
    charts: {
      title: '상태 차트',
      description:
        'CPU, 메모리, 센서, GPU, 네트워크, 디스크, 호스트 상태를 모바일 차트로 확인합니다.',
    },
    workspace: {
      title: '크로스 플랫폼 작업 공간',
      description:
        'iOS, Android, macOS, Linux, Windows에서 같은 Flutter 인터페이스를 사용합니다.',
    },
    terminal: {
      title: 'SSH 터미널과 SFTP',
      description:
        '서버 카드에서 바로 터미널과 파일 세션을 열 수 있으며 dartssh2와 xterm.dart를 사용합니다.',
    },
    native: {
      title: '네이티브 기기 기능',
      description:
        '생체 인증, 푸시 알림, 홈 위젯, watchOS 지원으로 서버 상태를 가까이에 둡니다.',
    },
    platforms: {
      title: 'Docker, 프로세스, systemd',
      description:
        '모니터링 흐름을 벗어나지 않고 컨테이너, 프로세스, 서비스를 확인합니다.',
    },
  },
  capabilities: {
    title: '모든 도구를 하나의 앱에.',
    subtitle:
      'ServerBox는 터미널, 파일 전송, 서비스 점검, 하드웨어 상태, 기기 알림을 같은 흐름에 둡니다.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux, Windows',
  },
  themes: {
    title: '원하는 모습으로.',
    subtitle:
      'ServerBox 공식 테마로, 앱의 테마 스토어와 같은 목록입니다. 앱의 설정 → 모양 → 테마 스토어에서 설치하거나, 패키지를 내려받아 테마 설치 → 파일을 선택하세요.',
    empty:
      '아직 공식 테마가 없습니다. 테마는 manifest.toml이 있는 폴더로, 라이트·다크 색상, 컴포넌트 스타일, 아이콘, 배경, 스플래시를 지정할 수 있습니다. 만드는 방법과 스토어에 올리는 방법은 가이드를 참고하세요.',
    note: '앱은 스토어 패키지를 설치하기 전에 SHA-256을 검증합니다.',
    authoring: '테마 만들기',
    download: '.fsbt 내려받기',
    source: '소스',
    light: '라이트',
    dark: '다크',
    search: '테마 검색',
    modeLabel: '모드',
    all: '전체',
    sortLabel: '정렬',
    sortName: '이름',
    sortUpdated: '최근 업데이트',
    noMatch: '일치하는 테마가 없습니다. 다른 이름이나 모드로 찾아 보세요.',
    storeTitle: '테마 스토어',
    storeSubtitle:
      'ServerBox 공식 테마를 앱이 그리는 모습 그대로 보여 줍니다. 색상, 컴포넌트, 아이콘, 스플래시를 확인하고, 앱의 테마 스토어에서 설치하거나 패키지를 내려받으세요.',
    browse: '테마 스토어 열기',
    back: '모든 테마',
    details: '자세히',
    icons: '아이콘',
    tabIcons: '탭과 선택 상태',
    navIcons: '기호',
    palette: '색상',
    components: '컴포넌트',
    splash: '스플래시',
    install: '설치',
    installSteps:
      '앱에서 설정 → 모양 → 테마 스토어를 열고 {name}을(를) 선택하세요. 패키지를 내려받아 테마 설치 → 파일을 선택해도 됩니다.',
    base: '기본',
    hovered: '호버',
    pressed: '누름',
    disabled: '비활성',
    loadFailed: '이 테마의 미리보기를 불러오지 못했습니다.',
    retry: '다시 시도',
    previewNote:
      '미리보기는 테마의 아이콘과 색상만 보여 줍니다. 나머지 화면은 참고용입니다.',
  },
  plugins: {
    title: '플러그인.',
    subtitle: 'ServerBox 공식 플러그인으로, 앱의 플러그인 스토어에서 설치합니다.',
    empty: '아직 공식 플러그인이 없습니다.',
    download: '내려받기',
  },
  download: {
    title: '모든 플랫폼, 모든 배포 경로.',
    subtitle:
      '기기에 맞는 신뢰할 수 있는 배포 경로를 선택하세요. iOS 버전은 App Store에서 받을 수 있습니다. macOS App Store 버전은 Apple silicon만 지원하며, Intel Mac에서는 GitHub Releases 또는 Homebrew로 설치할 수 있습니다. Android, Linux, Windows용 직접 다운로드도 제공됩니다.',
    copied: '설치 명령을 복사했습니다',
    copyPrompt: '이 설치 명령을 복사하세요:',
    note:
      '신뢰할 수 있는 출처에서만 패키지를 다운로드하세요. 서버 푸시, 위젯, companion 모니터링에는 서버에 ServerBoxMonitor를 별도로 설치하세요.',
  },
  cta: {
    title: 'ServerBox는 AGPLv3 기반의 무료 오픈소스입니다.',
    subtitle:
      'App Store, GitHub Releases, F-Droid 또는 OpenAPK에서 설치할 수 있습니다.',
    appStoreAction: 'App Store 열기',
    githubAction: 'GitHub Releases에서 다운로드',
  },
  footer: {
    features: '기능',
    capabilities: '도구',
    releases: '릴리스',
  },
  monitor: {
    meta: {
      title: 'ServerBox Monitor — 서버를 지켜보는 에이전트',
      description: 'ServerBox Monitor는 서버에서 실행되며 상태 기록을 남기고, 휴대폰으로 알림을 보내고, 위젯과 Watch 앱을 최신으로 유지하며, 웹 패널을 제공합니다.',
    },
    nav: {
      why: '왜 에이전트인가',
      panel: '웹 패널',
      alerts: '알림',
      access: '권한',
      install: '설치',
    },
    hero: {
      eyebrow: 'ServerBox Monitor',
      title: '7초마다 측정하고, 기록하고, 휴대폰에 알립니다.',
      subtitle: '서버에서 실행되는 작은 Rust 에이전트입니다. 상태 기록을 SQLite에 저장하고, 알림을 보내고, ServerBox 위젯과 Watch 앱을 최신으로 유지하며, 웹 패널을 제공합니다. 앱은 SSH 없이 에이전트에 연결합니다.',
      installLabel: 'systemd 또는 OpenRC를 쓰는 Linux에 설치',
      installNote: 'root가 아닌 내 계정으로 실행됩니다.',
      copy: '복사',
      copied: '복사됨',
      guide: '설정 가이드',
      terminalLabel: '설치된 뒤 측정을 시작하는 에이전트',
      installed: 'systemctl --user 서비스로 설치됨',
      listening: '0.0.0.0:3770에서 대기 중',
      sampled: '측정',
      cadence: '7초마다 — interval_seconds 기본값',
      pushLabel: 'iPhone 잠금 화면에 표시된 에이전트 알림',
      widgetLabel: '에이전트의 데이터를 보여 주는 ServerBox 홈 화면 위젯',
    },
    keywords: {
      history: 'SQLite 기록',
      push: '푸시 알림',
      panel: '웹 패널',
      roles: '역할과 권한',
      docker: 'Docker',
    },
    why: {
      title: '에이전트가 SSH에 더해 주는 것',
      subtitle: '서버를 보는 데는 SSH로 충분합니다. 에이전트는 내가 보지 않을 때도 계속 지켜봅니다.',
      history: {
        title: '앱을 열기 전의 기록',
        description: '에이전트가 스스로 측정하고 결과를 남기므로, 잠든 사이의 밤도 그래프에 남습니다. 보관 기간은 직접 정합니다.',
      },
      alerts: {
        title: '휴대폰으로 오는 알림',
        description: 'CPU, 메모리, 스왑, 디스크, 네트워크, 온도에 대한 규칙을 iOS, Bark, ServerChan 또는 원하는 웹훅으로 보냅니다.',
      },
      widgets: {
        title: '늘 최신인 위젯과 Watch',
        description: '홈 화면 위젯과 Watch 앱이 에이전트에서 직접 읽어 오므로, ServerBox를 닫아 두어도 갱신됩니다.',
      },
      reach: {
        title: 'SSH를 열 필요 없음',
        description: '앱은 HTTP로 에이전트와 통신합니다. SSH가 닿지 않는 곳에서 쓰거나, 같은 서버에서 SSH와 함께 쓸 수 있습니다.',
      },
    },
    panel: {
      title: '모든 에이전트에 웹 패널',
      subtitle: '각 에이전트는 3770 포트에서 자체 패널을 제공합니다. 패널을 한 번만 배포해 한 페이지에서 여러 에이전트에 로그인할 수도 있습니다.',
      dashboard: {
        title: '실시간 그래프와 저장된 기록',
        description: 'CPU, 메모리, 디스크, 네트워크, GPU, 센서를 실시간으로, 그리고 에이전트가 남긴 기록까지 — 직접 만든 명령의 출력도 함께 보여 줍니다.',
      },
      terminal: {
        title: '브라우저 속 터미널과 파일',
        description: '탭을 닫아도 계속 실행되고 돌아오면 이어지는 터미널, 그리고 지정한 디렉터리로만 제한된 파일 탐색기.',
      },
      machine: {
        title: '머신에서 움직이는 부분들',
        description: 'Docker 또는 Podman 컨테이너, 서비스, 프로세스, cron, 방화벽, 시스템 사용자. 모든 작업은 에이전트가 만들고 검사하며, 패널은 요청만 합니다.',
      },
      reach: {
        title: '서버 옆에 있는 것들',
        description: 'RDP와 VNC 데스크톱, Redfish를 통한 BMC, Proxmox VE 또는 libvirt의 가상 머신에 에이전트를 거쳐 접속합니다.',
      },
    },
    alerts: {
      title: '이미 보고 있는 곳으로 오는 알림',
      subtitle: '규칙은 지표 하나와 임계값 하나입니다. 조건이 충족되면 설정한 모든 채널로 알립니다.',
      rule: 'config.toml의 규칙',
      push: 'iOS 푸시',
      webhook: '채팅 앱으로 보내는 웹훅',
      widget: '홈 화면 위젯',
    },
    access: {
      title: '계정마다 할 수 있는 일은 직접 정합니다',
      subtitle: '상태 보기는 모든 계정에 열려 있습니다. 나머지는 부여하는 것이며, 언제든 회수할 수 있습니다.',
      roles: {
        title: '역할과 권한',
        description: '셸, 파일, 포트 포워딩, 가상화는 관리자가 역할에 부여하는 권한입니다. 하나를 회수하면 그 권한을 쓰던 것이 바로 닫힙니다.',
      },
      transport: {
        title: '읽기 이상은 TLS 필요',
        description: '명령, 파일, 중계에는 TLS나 같은 호스트에서 온 요청이 필요합니다. 내장 TLS, 리버스 프록시, 터널 모두 됩니다.',
      },
      account: {
        title: '내 계정으로 실행',
        description: '설치 스크립트는 에이전트를 내 계정으로 실행합니다. 에이전트가 주는 셸은 root가 아니라 그 계정의 셸입니다.',
      },
      audit: {
        title: '모든 접근을 기록',
        description: '누가, 언제, 어디서, 무엇을, 결과는 어땠는지. 비밀번호와 키는 절대 기록하지 않습니다.',
      },
    },
    install: {
      title: '설치',
      subtitle: '새 서버에서 휴대폰으로 상태를 보기까지 세 단계.',
      step1: {
        title: '에이전트 설치',
        description: '설치 스크립트가 systemd나 OpenRC를 고르고 최신 릴리스를 받습니다. --permissions read를 붙이면 아무 권한 없는 관리자로 시작합니다.',
      },
      step2: {
        title: '로그인',
        description: '처음 시작할 때 admin 계정과 무작위 비밀번호가 만들어지고, 데이터베이스 옆 initial-admin-credentials.txt에 저장됩니다. 비밀번호를 바꾼 뒤 파일을 지우세요:',
      },
      step3: {
        title: 'ServerBox에 추가',
        description: '앱에서 주소와 계정으로 서버를 Monitor 에이전트로 추가합니다. 또는 3770 포트의 패널을 엽니다.',
      },
      tabs: {
        systemd: 'systemd',
        openrc: 'OpenRC (Alpine)',
        docker: 'Docker',
      },
      dockerNote: '이 저장소에서 빌드합니다.',
    },
    cta: {
      title: '앱처럼 무료이고 오픈 소스입니다.',
      subtitle: '에이전트는 같은 라이선스로 ServerBox 저장소에 있습니다.',
      app: 'ServerBox 받기',
      source: '에이전트 소스',
    },
  },
}

export default kr
