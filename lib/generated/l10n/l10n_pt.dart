import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get aboutThanks => 'Agradecimentos a todos os participantes.';

  @override
  String get acceptBeta => 'Aceitar atualizações da versão de teste';

  @override
  String get addSystemPrivateKeyTip => 'Atualmente, não há nenhuma chave privada. Gostaria de adicionar a chave do sistema (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Adicionado à lista de tarefas';

  @override
  String get addr => 'Endereço';

  @override
  String get alreadyLastDir => 'Já é o diretório mais alto';

  @override
  String get authFailTip => 'Autenticação falhou, por favor verifique se a senha/chave/host/usuário, etc., estão incorretos.';

  @override
  String get autoBackupConflict => 'Apenas um backup automático pode ser ativado por vez';

  @override
  String get autoConnect => 'Conexão automática';

  @override
  String get autoRun => 'Execução automática';

  @override
  String get autoUpdateHomeWidget => 'Atualização automática do widget da tela inicial';

  @override
  String get backupTip => 'Os dados exportados são criptografados de forma simples, por favor, guarde-os com segurança.';

  @override
  String get backupVersionNotMatch => 'Versão de backup não compatível, não é possível restaurar';

  @override
  String get battery => 'Bateria';

  @override
  String get bgRun => 'Execução em segundo plano';

  @override
  String get bgRunTip => 'Este interruptor indica que o programa tentará rodar em segundo plano, mas a capacidade de fazer isso depende das permissões concedidas. No Android nativo, desative a \'Otimização de bateria\' para este app, no MIUI, altere a estratégia de economia de energia para \'Sem restrições\'.';

  @override
  String get closeAfterSave => 'Salvar e fechar';

  @override
  String get cmd => 'Comando';

  @override
  String get collapseUITip => 'Deve colapsar listas longas na UI por padrão?';

  @override
  String get conn => 'Conectar';

  @override
  String get container => 'Contêiner';

  @override
  String get containerTrySudoTip => 'Por exemplo: se o usuário for definido como aaa dentro do app, mas o Docker estiver instalado sob o usuário root, esta opção precisará ser ativada';

  @override
  String get convert => 'Converter';

  @override
  String get copyPath => 'Copiar caminho';

  @override
  String get cpuViewAsProgressTip => 'Exiba a taxa de uso de cada CPU em estilo de barra de progresso (estilo antigo)';

  @override
  String get cursorType => 'Tipo de cursor';

  @override
  String get customCmd => 'Comandos personalizados';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands';

  @override
  String get customCmdHint => '\"Nome do comando\": \"Comando\"';

  @override
  String get decode => 'Decodificar';

  @override
  String get decompress => 'Descomprimir';

  @override
  String get deleteServers => 'Excluir servidores em lote';

  @override
  String get dirEmpty => 'Certifique-se de que a pasta está vazia';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get disk => 'Disco';

  @override
  String get diskIgnorePath => 'Caminhos de disco ignorados';

  @override
  String get displayCpuIndex => 'Exiba o índice de CPU';

  @override
  String dl2Local(Object fileName) {
    return 'Baixar $fileName para o local?';
  }

  @override
  String get dockerEmptyRunningItems => 'Não há contêineres em execução.\nIsso pode ser porque:\n- O usuário que instalou o Docker difere do usuário configurado no app\n- A variável de ambiente DOCKER_HOST não foi lida corretamente. Você pode verificar isso executando `echo \$DOCKER_HOST` no terminal.';

  @override
  String dockerImagesFmt(Object count) {
    return 'Total de $count imagens';
  }

  @override
  String get dockerNotInstalled => 'Docker não instalado';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount em execução, $stoppedCount parados';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count contêiner(es) em execução';
  }

  @override
  String get doubleColumnMode => 'Modo de coluna dupla';

  @override
  String get doubleColumnTip => 'Esta opção apenas ativa a funcionalidade, se ela será ativada depende também da largura do dispositivo';

  @override
  String get editVirtKeys => 'Editar teclas virtuais';

  @override
  String get editor => 'Editor';

  @override
  String get editorHighlightTip => 'O desempenho do destaque de código atualmente é ruim, pode optar por desativá-lo para melhorar.';

  @override
  String get encode => 'Codificar';

  @override
  String get envVars => 'Variável de ambiente';

  @override
  String get experimentalFeature => 'Recurso experimental';

  @override
  String get extraArgs => 'Argumentos extras';

  @override
  String get fallbackSshDest => 'Destino SSH de fallback';

  @override
  String get fdroidReleaseTip => 'Se você baixou este aplicativo do F-Droid, é recomendado desativar esta opção.';

  @override
  String get fgService => 'Serviço em primeiro plano';

  @override
  String get fgServiceTip => 'Após ativar, alguns modelos de dispositivos podem travar. Desativar pode fazer com que alguns modelos não consigam manter conexões SSH em segundo plano. Por favor, permita as permissões de notificação do ServerBox, execução em segundo plano e auto-despertar nas configurações do sistema.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Arquivo \'$file\' muito grande \'$size\', excedendo $sizeMax';
  }

  @override
  String get followSystem => 'Seguir sistema';

  @override
  String get font => 'Fonte';

  @override
  String get fontSize => 'Tamanho da fonte';

  @override
  String get force => 'Forçar';

  @override
  String get fullScreen => 'Modo tela cheia';

  @override
  String get fullScreenJitter => 'Tremulação em tela cheia';

  @override
  String get fullScreenJitterHelp => 'Prevenir burn-in de tela';

  @override
  String get fullScreenTip => 'Deve ser ativado o modo de tela cheia quando o dispositivo é girado para o modo paisagem? Esta opção aplica-se apenas à aba do servidor.';

  @override
  String get goBackQ => 'Voltar?';

  @override
  String get goto => 'Ir para';

  @override
  String get hideTitleBar => 'Ocultar barra de título';

  @override
  String get highlight => 'Destaque de código';

  @override
  String get homeWidgetUrlConfig => 'Configuração de URL do widget da tela inicial';

  @override
  String get host => 'Host';

  @override
  String httpFailedWithCode(Object code) {
    return 'Falha na solicitação, código de status: $code';
  }

  @override
  String get ignoreCert => 'Ignorar certificado';

  @override
  String get image => 'Imagem';

  @override
  String get imagesList => 'Lista de imagens';

  @override
  String get init => 'Inicializar';

  @override
  String get inner => 'Interno';

  @override
  String get install => 'Instalar';

  @override
  String get installDockerWithUrl => 'Por favor, instale o Docker primeiro em https://docs.docker.com/engine/install';

  @override
  String get invalid => 'Inválido';

  @override
  String get jumpServer => 'Servidor de salto';

  @override
  String get keepForeground => 'Por favor, mantenha o app em primeiro plano!';

  @override
  String get keepStatusWhenErr => 'Manter o status anterior do servidor';

  @override
  String get keepStatusWhenErrTip => 'Limitado a erros de execução de scripts';

  @override
  String get keyAuth => 'Autenticação por chave';

  @override
  String get letterCache => 'Cache de letras';

  @override
  String get letterCacheTip => 'Recomendado desativar, mas após desativar, será impossível inserir caracteres CJK.';

  @override
  String get license => 'Licença de código aberto';

  @override
  String get location => 'Localização';

  @override
  String get loss => 'Taxa de perda';

  @override
  String madeWithLove(Object myGithub) {
    return 'Feito com ❤️ por $myGithub';
  }

  @override
  String get manual => 'Manual';

  @override
  String get max => 'Máximo';

  @override
  String get maxRetryCount => 'Número de tentativas de reconexão com o servidor';

  @override
  String get maxRetryCountEqual0 => 'Irá tentar indefinidamente';

  @override
  String get min => 'Mínimo';

  @override
  String get mission => 'Missão';

  @override
  String get more => 'Mais';

  @override
  String get moveOutServerFuncBtnsHelp => 'Ativado: Mostra abaixo de cada cartão na aba do servidor. Desativado: Mostra no topo da página de detalhes do servidor.';

  @override
  String get ms => 'ms';

  @override
  String get needHomeDir => 'Se você é usuário de Synology, [veja aqui](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Usuários de outros sistemas precisam pesquisar como criar um diretório home.';

  @override
  String get needRestart => 'Necessita reiniciar o app';

  @override
  String get net => 'Rede';

  @override
  String get netViewType => 'Tipo de visualização de rede';

  @override
  String get newContainer => 'Novo contêiner';

  @override
  String get noLineChart => 'Não usar gráficos de linha';

  @override
  String get noLineChartForCpu => 'Não utilizar gráficos de linhas para a CPU';

  @override
  String get noPrivateKeyTip => 'A chave privada não existe, pode ter sido deletada ou há um erro de configuração.';

  @override
  String get noPromptAgain => 'Não perguntar novamente';

  @override
  String get node => 'Nó';

  @override
  String get notAvailable => 'Indisponível';

  @override
  String get onServerDetailPage => 'Na página de detalhes do servidor';

  @override
  String get onlyOneLine => 'Exibir apenas como uma linha (rolável)';

  @override
  String get onlyWhenCoreBiggerThan8 => 'Efetivo apenas quando o número de núcleos > 8';

  @override
  String get openLastPath => 'Abrir o último caminho';

  @override
  String get openLastPathTip => 'Registros diferentes para servidores diferentes, e registra o caminho ao sair';

  @override
  String get parseContainerStatsTip => 'Análise de status do Docker pode ser lenta';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% de $size';
  }

  @override
  String get permission => 'Permissões';

  @override
  String get pingAvg => 'Média:';

  @override
  String get pingInputIP => 'Por favor, insira o IP ou domínio alvo';

  @override
  String get pingNoServer => 'Nenhum servidor disponível para Ping\nPor favor, adicione um servidor na aba de servidores e tente novamente';

  @override
  String get pkg => 'Gerenciamento de pacotes';

  @override
  String get plugInType => 'Tipo de Inserção';

  @override
  String get port => 'Porta';

  @override
  String get preview => 'Pré-visualização';

  @override
  String get privateKey => 'Chave privada';

  @override
  String get process => 'Processo';

  @override
  String get pushToken => 'Token de notificação push';

  @override
  String get pveIgnoreCertTip => 'Não recomendado para ativar, cuidado com os riscos de segurança! Se estiver usando o certificado padrão do PVE, você precisa habilitar esta opção.';

  @override
  String get pveLoginFailed => 'Falha no login. Não é possível autenticar com o nome de usuário/senha da configuração do servidor para login no Linux PAM.';

  @override
  String get pveVersionLow => 'Esta funcionalidade está atualmente em fase de teste e foi testada apenas no PVE 8+. Por favor, use com cautela.';

  @override
  String get pwd => 'Senha';

  @override
  String get read => 'Leitura';

  @override
  String get reboot => 'Reiniciar';

  @override
  String get rememberPwdInMem => 'Lembrar senha na memória';

  @override
  String get rememberPwdInMemTip => 'Usado para contêineres, suspensão, etc.';

  @override
  String get rememberWindowSize => 'Lembrar o tamanho da janela';

  @override
  String get remotePath => 'Caminho remoto';

  @override
  String get restart => 'Reiniciar';

  @override
  String get result => 'Resultado';

  @override
  String get rotateAngel => 'Ângulo de rotação';

  @override
  String get route => 'Roteamento';

  @override
  String get run => 'Executar';

  @override
  String get running => 'Executando';

  @override
  String get sameIdServerExist => 'Já existe um servidor com o mesmo ID';

  @override
  String get save => 'Salvar';

  @override
  String get saved => 'Salvo';

  @override
  String get second => 'Segundo';

  @override
  String get sensors => 'Sensores';

  @override
  String get sequence => 'Sequência';

  @override
  String get server => 'Servidor';

  @override
  String get serverDetailOrder => 'Ordem dos componentes na página de detalhes do servidor';

  @override
  String get serverFuncBtns => 'Botões de função do servidor';

  @override
  String get serverOrder => 'Ordem do servidor';

  @override
  String get sftpDlPrepare => 'Preparando para conectar ao servidor...';

  @override
  String get sftpEditorTip => 'Se vazio, use o editor de arquivos integrado do aplicativo. Se houver um valor, use o editor do servidor remoto, por exemplo, `vim` (recomendado detectar automaticamente de acordo com `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Usar `rm -r` em SFTP para excluir pastas';

  @override
  String get sftpSSHConnected => 'SFTP conectado...';

  @override
  String get sftpShowFoldersFirst => 'Mostrar pastas primeiro';

  @override
  String get showDistLogo => 'Mostrar logo da distribuição';

  @override
  String get shutdown => 'Desligar';

  @override
  String get size => 'Tamanho';

  @override
  String get snippet => 'Snippet';

  @override
  String get softWrap => 'Quebra de linha suave';

  @override
  String get specifyDev => 'Especificar dispositivo';

  @override
  String get specifyDevTip => 'Por exemplo, as estatísticas de tráfego de rede são por padrão para todos os dispositivos. Você pode especificar um dispositivo específico aqui.';

  @override
  String get speed => 'Velocidade';

  @override
  String spentTime(Object time) {
    return 'Tempo gasto: $time';
  }

  @override
  String get sshTermHelp => 'Quando o terminal é rolável, arrastar horizontalmente pode selecionar texto. Clicar no botão do teclado ativa/desativa o teclado. O ícone de arquivo abre o SFTP do caminho atual. O botão da área de transferência copia o conteúdo quando o texto é selecionado e cola o conteúdo da área de transferência no terminal quando nenhum texto é selecionado e há conteúdo na área de transferência. O ícone de código cola trechos de código no terminal e os executa.';

  @override
  String sshTip(Object url) {
    return 'Esta funcionalidade está em fase de teste.\n\nPor favor, reporte problemas em $url ou junte-se a nós no desenvolvimento.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Desativação automática das teclas virtuais';

  @override
  String get start => 'Iniciar';

  @override
  String get stat => 'Estatísticas';

  @override
  String get stats => 'Estatísticas';

  @override
  String get stop => 'Parar';

  @override
  String get stopped => 'Parado';

  @override
  String get storage => 'Armazenamento';

  @override
  String get supportFmtArgs => 'Suporta os seguintes argumentos formatados:';

  @override
  String get suspend => 'Suspender';

  @override
  String get suspendTip => 'A função de suspensão requer permissões de root e suporte do systemd.';

  @override
  String switchTo(Object val) {
    return 'Mudar para $val';
  }

  @override
  String get sync => 'Sincronizar';

  @override
  String get syncTip => 'Pode ser necessário reiniciar para algumas mudanças surtirem efeito.';

  @override
  String get system => 'Sistema';

  @override
  String get tag => 'Tag';

  @override
  String get temperature => 'Temperatura';

  @override
  String get termFontSizeTip => 'Esta configuração afetará o tamanho do terminal (largura e altura). Você pode dar zoom na página do terminal para ajustar o tamanho da fonte da sessão atual.';

  @override
  String get terminal => 'Terminal';

  @override
  String get test => 'Teste';

  @override
  String get textScaler => 'Escala de texto';

  @override
  String get textScalerTip => '1.0 => 100% (tamanho original), afeta apenas algumas fontes na página do servidor, não é recomendado alterar.';

  @override
  String get theme => 'Tema';

  @override
  String get time => 'Tempo';

  @override
  String get times => 'Vezes';

  @override
  String get total => 'Total';

  @override
  String get traffic => 'Tráfego';

  @override
  String get trySudo => 'Tentar usar sudo';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => 'Desconhecido';

  @override
  String get unkownConvertMode => 'Modo de conversão desconhecido';

  @override
  String get update => 'Atualizar';

  @override
  String get updateIntervalEqual0 => 'Se definido como 0, o estado do servidor não será atualizado automaticamente.\nE o uso da CPU não poderá ser calculado.';

  @override
  String get updateServerStatusInterval => 'Intervalo de atualização do estado do servidor';

  @override
  String get upload => 'Upload';

  @override
  String get upsideDown => 'Inverter verticalmente';

  @override
  String get uptime => 'Tempo de atividade';

  @override
  String get useCdn => 'Utilizando CDN';

  @override
  String get useCdnTip => 'Recomenda-se que usuários não chineses usem CDN. Gostaria de usá-lo?';

  @override
  String get useNoPwd => 'Será usado sem senha';

  @override
  String get usePodmanByDefault => 'Usar Podman por padrão';

  @override
  String get used => 'Usado';

  @override
  String get view => 'Visualização';

  @override
  String get viewErr => 'Ver erro';

  @override
  String get virtKeyHelpClipboard => 'Se houver texto selecionado no terminal, copia para a área de transferência, caso contrário, cola o conteúdo da área de transferência no terminal.';

  @override
  String get virtKeyHelpIME => 'Ligar/desligar o teclado';

  @override
  String get virtKeyHelpSFTP => 'Abre o caminho atual em SFTP.';

  @override
  String get waitConnection => 'Por favor, aguarde a conexão ser estabelecida';

  @override
  String get wakeLock => 'Manter acordado';

  @override
  String get watchNotPaired => 'Não há Apple Watch pareado';

  @override
  String get webdavSettingEmpty => 'Configurações de Webdav estão vazias';

  @override
  String get whenOpenApp => 'Ao abrir o app';

  @override
  String get wolTip => 'Após configurar o WOL (Wake-on-LAN), um pedido de WOL é enviado cada vez que o servidor é conectado.';

  @override
  String get write => 'Escrita';

  @override
  String get writeScriptFailTip => 'Falha ao escrever no script, possivelmente devido à falta de permissões ou o diretório não existe.';

  @override
  String get writeScriptTip => 'Após conectar ao servidor, um script será escrito em ~/.config/server_box para monitorar o status do sistema. Você pode revisar o conteúdo do script.';
}
