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
    plugins: '플러그인',
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
      'App Store, GitHub Releases, F-Droid, OpenAPK 또는 프로젝트 CDN에서 설치할 수 있습니다.',
    appStoreAction: 'App Store 열기',
    githubAction: 'GitHub Releases에서 다운로드',
  },
  plugins: {
    metaTitle: 'ServerBox 플러그인 — 새 버전을 기다리지 않고 확장하기',
    metaDescription:
      '플러그인은 ServerBox에 페이지, 카드, 상태 항목을 더합니다. 각각 샌드박스에서 실행되는 작은 모듈이며 필요한 권한을 선언하고, 앱은 내려받은 모든 패키지를 검증합니다.',
    title: '새 버전을 기다리지 않고 확장하세요.',
    subtitle:
      '플러그인은 페이지, 카드, 홈 탭, 추가 상태 항목을 더합니다. 작은 모듈 하나가 샌드박스에서 실행되며, 매니페스트에 적고 사용자가 동의한 일만 할 수 있습니다.',
    how: {
      sandbox: {
        title: '샌드박스에서 실행',
        description:
          '플러그인은 격리된 런타임에서 도는 JavaScript입니다. 파일 시스템도, 네트워크도, 자체 서버 연결도 없이 필요한 일은 모두 앱에 요청합니다.',
      },
      permissions: {
        title: '먼저 요청하고 실행',
        description:
          '매니페스트에 필요한 것 — 명령 실행, 특정 호스트 접근, 서버 목록 조회 — 이 적혀 있고, 설치할 때 동의하는 것이 그 목록입니다. 허용되지 않은 호출은 그 자리에서 실패합니다.',
      },
      anyRepo: {
        title: '어떤 저장소든, 바이트를 검증',
        description:
          'HTTPS 저장소 주소라면 어디서든 설치할 수 있고(최신 트리를 요청 한 번으로 받아옵니다), 각 패키지를 플러그인 파일이 알려준 체크섬으로 검증합니다. 체크섬이 없는 패키지는 명시적으로 동의하지 않으면 거부됩니다.',
      },
    },
    listTitle: '공식 저장소의 플러그인',
    listSubtitle:
      '플러그인 {count}개. 소스는 이 저장소에 있고, 배포는 앱과 따로 이뤄집니다.',
    asks: '요청 권한',
    asksNothing: '없음',
    appearsIn: '표시 위치',
    languages: '언어',
    source: '소스',
    install: {
      title: '설치하기',
      stepOne: '앱에서 설정 → 플러그인 → 플러그인 스토어를 엽니다.',
      stepTwo: '플러그인을 고르고 설치를 누릅니다. 공식 저장소는 이미 등록되어 있습니다.',
      stepThree:
        '요청 권한을 읽고 동의하세요. 무엇이든 실행하기 전에 앱이 저장소의 체크섬으로 내려받은 파일을 검증합니다.',
      address: '공식 저장소를 지웠다가 다시 추가할 때 쓰는 주소:',
      copy: '주소 복사',
    },
    write: {
      title: '직접 만들기',
      description:
        '플러그인은 TypeScript나 JavaScript ES 모듈 하나이며, bun test로 모의 호스트를 상대로 테스트합니다 — 앱도 빌드 단계도 필요 없습니다. 데스크톱에서는 디렉터리를 직접 지정할 수 있어, 편집하고 다시 시작하면 그게 전부입니다.',
      sdk: 'SDK',
      examples: '예제 플러그인',
      repository: '공식 저장소',
    },
    home: '홈',
  },
  footer: {
    features: '기능',
    capabilities: '도구',
    releases: '릴리스',
  },
}

export default kr
