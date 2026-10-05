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
}

export default kr
