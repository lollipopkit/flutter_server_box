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
    four: 'ServerBox 도구 스크린샷',
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
    items: {
      statusChart: '상태 차트',
      sshTerminal: 'SSH 터미널',
      sftp: 'SFTP',
      docker: 'Docker',
      process: '프로세스',
      systemd: 'Systemd',
      smart: 'S.M.A.R.T',
      gpu: 'GPU',
      sensors: '센서',
      push: '푸시',
      homeWidget: '홈 위젯',
      watchos: 'watchOS',
    },
  },
  download: {
    title: '모든 플랫폼, 모든 배포 경로.',
    subtitle:
      '기기와 신뢰 모델에 맞는 채널을 선택하세요. iOS는 App Store, macOS는 App Store 또는 Homebrew, Android/Linux/Windows는 직접 패키지를 제공합니다.',
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
  footer: {
    features: '기능',
    capabilities: '도구',
    releases: '릴리스',
  },
}

export default kr
