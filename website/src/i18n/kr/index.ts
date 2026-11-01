import type { Translation } from '../i18n-types.js'

const kr: Translation = {
  meta: {
    lang: 'ko',
    title: 'ServerBox — 서버 모니터링, SSH, 관리 도구를 하나의 앱으로',
    description:
      'ServerBox는 상태 차트, SSH 터미널, SFTP, Docker, 프로세스 및 systemd 관리, S.M.A.R.T. 모니터링, 푸시 알림, 위젯, watchOS를 지원해 Linux, Unix, Windows 서버를 관리할 수 있습니다.',
  },
  nav: {
    features: '기능',
    capabilities: '도구',
    download: '다운로드',
    docs: '문서',
    themes: '테마',
    os: 'ServerBox OS',
    plugins: '플러그인',
    languageLabel: '언어',
  },
  hero: {
    titlePrefix: '서버 상태를,',
    titleSuffix: '손안에서 확인하세요.',
    subtitle:
      'ServerBox는 상태 차트, SSH 터미널, SFTP, Docker, 프로세스 관리, systemd, S.M.A.R.T. 모니터링, 푸시 알림, 위젯, watchOS 지원을 하나의 앱에 담았습니다.',
    primaryAction: 'ServerBox 다운로드',
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
    title: '일상적인 서버 관리에 필요한 도구를 한곳에 모았습니다.',
    subtitle:
      '필수 기능을 간결하게 담았으며, 각 기능은 실제 서버 관리 작업에 맞춰져 있습니다.',
    list: {
      title: '서버 목록',
      description:
        '각 서버의 연결 상태와 CPU, 메모리, 디스크, 네트워크 사용량을 확인하세요. 태그로 필터링하거나 지구본에서 위치를 볼 수 있습니다.',
    },
    charts: {
      title: '상태 차트',
      description:
        'CPU, 메모리, 스왑, 디스크, 디스크 I/O, 네트워크를 실시간 차트로 확인하고 센서, GPU, 배터리 정보도 볼 수 있습니다. 기록 보기로 전환하거나 지표를 선택해 자세한 내용을 확인하세요.',
    },
    terminal: {
      title: 'SSH 터미널',
      description:
        '휴대폰에서도 가상 키를 사용해 htop, vim 등을 실행할 수 있는 완전한 터미널입니다. 직접 연결, 점프 호스트, ProxyCommand를 지원합니다.',
    },
    files: {
      title: 'SFTP 파일',
      description:
        '파일을 탐색하고 업로드·다운로드하거나 바로 편집할 수 있습니다. Markdown 파일은 미리 보기로 열립니다.',
    },
    containers: {
      title: 'Docker와 Podman',
      description:
        'Compose 프로젝트별 컨테이너와 CPU, 메모리, 네트워크 사용량을 확인합니다. 컨테이너를 시작·중지·재시작·삭제하고, 로그를 보거나 내부에서 셸을 열 수 있습니다. 이미지와 설정은 별도 탭에 있습니다.',
    },
    processes: {
      title: '프로세스',
      description:
        '모든 프로세스와 CPU·메모리 사용량을 확인하세요. 원하는 기준으로 정렬하고 이름, 사용자, PID로 검색하거나 목록에서 바로 종료할 수 있습니다.',
    },
    services: {
      title: 'Systemd 서비스',
      description:
        '실패한 systemd unit을 목록 맨 위에 표시합니다. 한 번 탭해 unit을 다시 시작하거나 로그를 확인하세요.',
    },
    users: {
      title: '사용자와 그룹',
      description:
        '시스템 계정과 로그인 셸, sudo 권한을 확인하세요. 사용자를 추가하거나 삭제하고 그룹을 추가·편집·삭제할 수 있습니다.',
    },
    agent: {
      title: 'AI 에이전트',
      description:
        '앱에 내장된 어시스턴트로 서버를 관리하고 원하는 모델 제공자, MCP 서버, 스킬을 연결할 수 있습니다.',
    },
    bench: {
      title: '벤치마크',
      description:
        'Yet Another Bench Script로 서버의 디스크, 네트워크, CPU를 측정하고 결과를 저장하세요. 더보기 메뉴에서 snippet, 원격 데스크톱, 가상화에도 접근할 수 있습니다.',
    },
    virt: {
      title: '가상화',
      description:
        'libvirt와 Proxmox VE의 VM과 컨테이너를 관리하세요. 시작·중지, vCPU·메모리·디스크 변경, 콘솔 열기를 지원합니다.',
    },
    themes: {
      title: '테마 스토어',
      description:
        '고유한 색상, 배경, 스플래시를 가진 공식 테마를 앱 안에서 설치합니다. 직접 만들 수도 있습니다.',
    },
  },
  capabilities: {
    title: '모든 도구를 하나의 앱에.',
    subtitle:
      'ServerBox는 터미널 연결, 파일 전송, 서비스 상태 확인, 하드웨어 모니터링, 기기 알림을 하나의 작업 흐름으로 제공합니다.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux, Windows',
  },
  os: {
    metaTitle: 'ServerBox OS — ServerBox의 서버 측',
    metaDescription:
      'ServerBox OS는 서버에서 실행되는 ServerBox Monitor입니다. 앱 스토어, 스토리지, Agent mode, 알림, 백업을 갖춘 브라우저 데스크톱입니다. Linux에 설치하거나 전체 시스템으로 부팅할 수 있습니다.',
    heroTitle: 'ServerBox OS',
    tagline: 'ServerBox의 서버 측.',
    subtitle:
      'ServerBox Monitor는 서버 자체에서 실행됩니다. 앱이 여기에 연결되며, 브라우저에 내장된 데스크톱으로 앱 없이도 머신을 관리할 수 있습니다. 기존 Linux 서버에 설치하거나 전체 시스템으로 부팅할 수 있습니다.',
    installAction: 'Linux에 설치',
    images: '이미지 다운로드',
    previewAction: '데모 보기',
    previewTitle: '실제 동작',
    previewSubtitle:
      'ServerBox OS는 베타 버전입니다. 실제 서버에서의 짧은 데모: 브라우저 속 데스크톱, 앱, 그리고 Agent 모드의 실제 동작.',
    previewPlay: 'ServerBox OS 데모 재생',
    previewYoutube: 'YouTube에서 보기',
    featuresTitle: '서버에서 실행되는 기능',
    featuresSubtitle: '머신에서 하나의 프로그램을 실행하고 브라우저나 앱에서 접속합니다.',
    desk: {
      title: '브라우저 안의 데스크톱',
      description:
        '서버 주소를 열면 상태, 파일, 터미널, 컨테이너, 프로세스, 서비스 등 각 기능이 창 안의 앱으로 표시됩니다.',
    },
    apps: {
      title: '앱 스토어',
      description:
        'Docker Compose로 Immich, Jellyfin, Gitea, Home Assistant 등 40개 이상의 자체 호스팅 서비스를 배포하고, Tailscale, 리버스 프록시, 커널, 로컬 AI 모델용 앱을 추가할 수 있습니다.',
    },
    storage: {
      title: '스토리지와 공유',
      description:
        '디스크를 파티션·포맷·마운트하고 RAID 배열과 ZFS 풀을 만들며 S.M.A.R.T.를 확인할 수 있습니다. SMB와 NFS로 폴더를 공유할 수도 있습니다.',
    },
    agent: {
      title: 'Agent mode',
      description:
        '머신에서 AI Agent가 작업을 수행하도록 요청하세요. 작업을 계획하고 위험한 명령 전에 확인하며, 허용한 경우에만 sudo를 사용하고 MCP를 통해 배포된 앱에 접근합니다.',
    },
    alerts: {
      title: '알림',
      description:
        'CPU, 메모리, 디스크, 서비스 규칙에 따라 앱, Telegram, Discord, ntfy, Bark, ServerChan, 이메일 또는 webhook으로 알림을 보냅니다.',
    },
    backups: {
      title: '백업',
      description:
        '설정은 age로 암호화해 WebDAV에 백업하고, 컨테이너 데이터는 선택한 디스크에 일정에 따라 백업합니다.',
    },
    security: {
      title: '하나의 비밀번호',
      description:
        '계정 하나로 비밀번호를 사용해 로그인합니다. 읽기 이외의 작업에는 HTTPS가 필요하며, 자격 증명은 저장 시 암호화되고 로그인과 root 작업은 감사 기록에 남습니다.',
    },
    app: {
      title: '앱과 함께 사용',
      description:
        'ServerBox에서 SSH 대신 HTTPS로 서버를 추가하거나 둘 다 사용할 수 있습니다. 휴대폰에서 상태와 기록을 확인하고 터미널, 파일, Agent mode 작업, 웹 앱을 이용하세요.',
    },
    installTitle: '두 가지 실행 방법',
    installSubtitle: '기존 Linux 서버에서 실행하거나 전용 머신의 전체 시스템으로 부팅할 수 있습니다.',
    linuxTitle: 'Linux 서버에서 실행',
    promptUser: '# systemd: 본인 계정으로 실행되는 사용자 서비스',
    promptOpenrc: '# OpenRC (Alpine): root가 서비스를 작성하지만 서비스는 계속 본인 계정으로 실행',
    promptRoot: '# 두 init 시스템 모두 root로 실행',
    linuxNote:
      '실행에 사용하는 계정에 따라 수행할 수 있는 작업이 달라집니다. 업데이트하거나 제거하려면 install을 upgrade 또는 uninstall로 바꾸세요.',
    copy: '설치 명령 복사',
    imageTitle: '전체 시스템으로 실행',
    stepWrite: '이미지를 다운로드해 USB 드라이브(dd, Etcher, Ventoy)에 기록하거나 가상 머신에 연결하세요.',
    stepBoot:
      '부팅하면 콘솔에 접속할 주소, 비교할 인증서 지문, 초기 비밀번호 위치가 표시됩니다.',
    stepInstall: 'sbm-install <디스크>는 해당 디스크를 지우고 시스템을 설치합니다.',
    liveNote:
      '설치 전에는 메모리에서 실행되므로 재부팅하면 데이터베이스, 이미지, 앱 데이터가 사라집니다.',
    note: 'ServerBox OS는 앱과 마찬가지로 AGPLv3 오픈소스입니다.',
    docs: 'Monitor 문서',
    appAction: '앱 받기',
  },
  themes: {
    title: '원하는 모습으로.',
    subtitle:
      '여기에 소개된 ServerBox 공식 테마는 앱 내 테마 스토어에서도 이용할 수 있습니다. 설정 → 모양 → 테마 스토어에서 설치하거나 패키지를 내려받아 테마 설치 → 파일을 선택하세요.',
    empty:
      '아직 공식 테마가 없습니다. 각 테마는 manifest.toml이 포함된 폴더이며 라이트·다크 색상, 컴포넌트 스타일, 아이콘, 배경, 시작 화면을 지정합니다. 테마를 만들고 스토어에 제출하는 방법은 가이드를 참고하세요.',
    note: '앱은 테마 스토어에서 패키지를 설치하기 전에 SHA-256을 확인합니다.',
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
      'ServerBox의 모든 공식 테마를 앱에서 보이는 그대로 소개합니다. 색상, 컴포넌트, 아이콘, 시작 화면을 확인하고 테마 스토어에서 설치하거나 패키지를 내려받으세요.',
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
      '앱에서 “설정 → 모양 → 테마 스토어”를 열고 {name}을(를) 선택하세요. 또는 패키지를 내려받아 “테마 설치 → 파일”을 선택하세요.',
    base: '기본',
    hovered: '호버',
    pressed: '누름',
    disabled: '비활성',
    loadFailed: '이 테마의 미리보기를 불러오지 못했습니다.',
    retry: '다시 시도',
    iconPacks: '아이콘 팩',
    iconPacksSubtitle:
      '아이콘 팩은 테마와 별도로 선택해 현재 테마와 함께 사용할 수 있습니다. 앱에서 “설정 → 모양 → 테마 스토어 → 아이콘 팩”을 열어 설치하세요.',
  },
  plugins: {
    title: 'ServerBox 확장하기',
    subtitle: 'ServerBox 공식 플러그인을 설치해 앱의 기능을 확장할 수 있습니다.',
    empty: '아직 공식 플러그인이 없습니다.',
    download: '내려받기',
  },
  download: {
    title: '다양한 플랫폼과 다운로드 방법을 지원합니다.',
    subtitle:
      '신뢰할 수 있는 다운로드 경로를 선택하세요. iOS는 App Store에서 받거나 GitHub Releases에서 서명되지 않은 .ipa 파일을 내려받아 직접 서명할 수 있습니다. Apple silicon 및 Intel용 macOS 버전은 GitHub Releases와 Homebrew에서 제공됩니다. Android, Linux, Windows는 설치 파일을 직접 내려받을 수 있습니다.',
    copied: '설치 명령을 복사했습니다',
    copyPrompt: '이 설치 명령을 복사하세요:',
    note:
      '신뢰할 수 있는 출처에서만 패키지를 내려받으세요. 서버 푸시 알림, 위젯 데이터, 독립 모니터링을 사용하려면 서버에 ServerBox OS를 설치하세요.',
  },
  cta: {
    title: 'ServerBox는 AGPLv3 기반의 무료 오픈소스입니다.',
    subtitle:
      'App Store, GitHub Releases, F-Droid 또는 OpenAPK에서 내려받을 수 있습니다.',
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
