// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get acceptBeta => 'Aceitar atualizações da versão de teste';

  @override
  String get addSystemPrivateKeyTip =>
      'Atualmente, não há nenhuma chave privada. Gostaria de adicionar a chave do sistema (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Adicionado à lista de tarefas';

  @override
  String get addr => 'Endereço';

  @override
  String get askAi => 'Perguntar à IA';

  @override
  String get ai => 'AI';

  @override
  String get askAiApiKey => 'Chave de API';

  @override
  String get askAiAwaitingResponse => 'Aguardando resposta da IA...';

  @override
  String get askAiBaseUrl => 'URL base';

  @override
  String get askAiEndpointTip =>
      'Enter a service base URL or a full Chat Completions or Responses endpoint. ServerBox completes the path for the selected protocol.';

  @override
  String get askAiProtocol => 'API protocol';

  @override
  String get askAiProtocolTip =>
      'Auto uses Responses for the official OpenAI endpoint and Chat Completions for compatible providers.';

  @override
  String get askAiProtocolAuto => 'Auto';

  @override
  String get askAiProtocolChatCompletions => 'Chat Completions';

  @override
  String get askAiProtocolResponses => 'Responses';

  @override
  String get askAiCommandInserted => 'Comando inserido no terminal';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Configure $fields nas configurações.';
  }

  @override
  String get askAiConfirmExecute => 'Confirmar antes de executar';

  @override
  String get askAiConversation => 'Conversa com a IA';

  @override
  String get askAiDisclaimer => 'A IA pode errar. Use com cautela.';

  @override
  String get askAiFollowUpHint => 'Faça uma pergunta adicional...';

  @override
  String get askAiInsertTerminal => 'Inserir no terminal';

  @override
  String get askAiNoResponse => 'Sem resposta';

  @override
  String get askAiRecommendedCommand => 'Comando sugerido pela IA';

  @override
  String get askAiSelectedContent => 'Conteúdo selecionado';

  @override
  String get askAiUsageHint => 'Usado no terminal SSH';

  @override
  String get askAiAgentTitle => 'SSH Agent';

  @override
  String get askAiAgentWelcome => 'What should we do on this server?';

  @override
  String get askAiAgentWelcomeTip =>
      'Ask for a diagnosis or a task. The Agent proposes one command at a time and waits for review before making changes.';

  @override
  String get askAiAgentPromptHint =>
      'Ask the Agent to inspect or fix something...';

  @override
  String get askAiAgentSend => 'Send to Agent';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analyze the selected terminal content, explain what happened, and propose the safest next step if action is needed.';

  @override
  String get askAiTerminalContext => 'Terminal context';

  @override
  String get askAiReady => 'Ready';

  @override
  String get askAiThinking => 'Thinking';

  @override
  String get askAiRunningCommand => 'Running';

  @override
  String get askAiReviewNeeded => 'Review';

  @override
  String get askAiReviewAction => 'Review proposed command';

  @override
  String get askAiReviewBeforeContinuing =>
      'Review or decline the proposed command first';

  @override
  String get askAiApproveRun => 'Approve & run';

  @override
  String get askAiDecline => 'Decline';

  @override
  String get askAiActionDeclined => 'The proposed command was declined.';

  @override
  String get askAiInterrupted => 'Agent response was interrupted.';

  @override
  String get askAiRiskReadOnly => 'Read-only';

  @override
  String get askAiRiskCaution => 'Changes system';

  @override
  String get askAiRiskDestructive => 'High risk';

  @override
  String get askAiHighRiskConfirmTitle => 'Run high-risk command?';

  @override
  String get askAiHighRiskConfirmBody =>
      'This command may delete data, stop services, or otherwise be difficult to undo. Review it carefully before running.';

  @override
  String get askAiCommandCancelled => 'Cancelled';

  @override
  String get askAiCommandTimedOut => 'Timed out';

  @override
  String get askAiNoCommandOutput => 'Command completed without output.';

  @override
  String get askAiOutputTruncated =>
      'Long output was truncated before it was sent back to the Agent.';

  @override
  String get askAiAutoApproved => 'Auto-approved';

  @override
  String get askAiAutoRunSafeCommands => 'Auto-run read-only commands';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Only auto-run when both the model and local safety checks classify the command as read-only. Commands that change the system still require review.';

  @override
  String get askAiSendOnEnter => 'Enter sends';

  @override
  String get askAiSendOnEnterTip =>
      'Enter sends the message, Shift+Enter starts a new line. Off swaps them: Enter starts a new line and Cmd/Ctrl+Enter sends.';

  @override
  String get askAiApiKeyOptional =>
      'Optional for local or unauthenticated endpoints';

  @override
  String get askAiHistory => 'Conversation history';

  @override
  String get askAiHistoryLocalOnly =>
      'Encrypted on this device and excluded from backup and sync';

  @override
  String get askAiNewConversation => 'New conversation';

  @override
  String get askAiNoHistory => 'No saved conversations for this server';

  @override
  String get askAiNoHistoryMessages => 'No messages yet';

  @override
  String get askAiUntitledConversation => 'New conversation';

  @override
  String get askAiRenameConversation => 'Rename conversation';

  @override
  String get askAiDeleteConversationTitle => 'Delete this conversation?';

  @override
  String get askAiDeleteConversationTip =>
      'This removes the conversation from this device and cannot be undone.';

  @override
  String get askAiClearHistory => 'Clear history';

  @override
  String get askAiClearHistoryTitle => 'Clear this server\'s Agent history?';

  @override
  String get askAiClearHistoryTip =>
      'All Agent conversations saved for this server will be removed from this device.';

  @override
  String get askAiRestoredReview =>
      'Restored from history. Review it again before running; it will never run automatically.';

  @override
  String get agentTitle => 'Agent';

  @override
  String get agentWelcome => 'What should we do across your servers?';

  @override
  String get agentWelcomeTip =>
      'Ask for a diagnosis or an operational task. The Agent uses live ServerBox state and proposes one reviewed action at a time.';

  @override
  String get agentPromptHint =>
      'Ask the Agent to inspect or operate your servers...';

  @override
  String get agentNoServers => 'No configured servers';

  @override
  String get agentNoHistory => 'No saved global Agent conversations';

  @override
  String get agentClearHistoryTitle => 'Clear global Agent history?';

  @override
  String get agentClearHistoryTip =>
      'All global Agent conversations will be removed from this device.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Read file';

  @override
  String get agentToolWriteFile => 'Write file';

  @override
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => 'Tool execution failed.';

  @override
  String get atLeastOneTab => 'Pelo menos uma aba deve ser selecionada';

  @override
  String get authFailTip =>
      'Autenticação falhou, por favor verifique se a senha/chave/host/usuário, etc., estão incorretos.';

  @override
  String get autoBackupConflict =>
      'Apenas um backup automático pode ser ativado por vez';

  @override
  String get autoConnect => 'Conexão automática';

  @override
  String get autoRun => 'Execução automática';

  @override
  String get autoUpdateHomeWidget =>
      'Atualização automática do widget da tela inicial';

  @override
  String get availableTabs => 'Abas disponíveis';

  @override
  String get backupEncrypted => 'Backup está criptografado';

  @override
  String get backupNotEncrypted => 'Backup não está criptografado';

  @override
  String get backupPassword => 'Senha de backup';

  @override
  String get backupPasswordRemoved => 'Senha de backup removida';

  @override
  String get backupPasswordSet => 'Senha de backup definida';

  @override
  String get backupPasswordTip =>
      'Defina uma senha para criptografar arquivos de backup. Deixe vazio para desabilitar a criptografia.';

  @override
  String get backupPasswordWrong => 'Senha de backup incorreta';

  @override
  String get backupTip =>
      'Os dados exportados podem ser criptografados com senha. \nPor favor, guarde-os com segurança.';

  @override
  String get icloudBackupStatusTitle => 'Backup status';

  @override
  String get icloudBackupStatusLoading => 'Loading iCloud backup status...';

  @override
  String get icloudBackupStatusError => 'Unable to read iCloud backup metadata';

  @override
  String get icloudBackupStatusEmpty => 'No iCloud backup file found yet';

  @override
  String get icloudBackupStateUploading => 'Uploading';

  @override
  String get icloudBackupStateConflict => 'Conflict detected';

  @override
  String get icloudBackupStateUploaded => 'Uploaded';

  @override
  String get icloudBackupStateWaiting => 'Waiting for iCloud';

  @override
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Last backup: $lastModified\nStatus: $remoteState';
  }

  @override
  String get bgRun => 'Execução em segundo plano';

  @override
  String get bgRunTip =>
      'Este interruptor indica que o programa tentará rodar em segundo plano, mas a capacidade de fazer isso depende das permissões concedidas. No Android nativo, desative a \'Otimização de bateria\' para este app, no MIUI, altere a estratégia de economia de energia para \'Sem restrições\'.';

  @override
  String get clearAllStatsContent =>
      'Tem certeza de que deseja limpar todas as estatísticas de conexão do servidor? Esta ação não pode ser desfeita.';

  @override
  String get clearAllStatsTitle => 'Limpar todas as estatísticas';

  @override
  String clearServerStatsContent(Object serverName) {
    return 'Tem certeza de que deseja limpar as estatísticas de conexão para o servidor \"$serverName\"? Esta ação não pode ser desfeita.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return 'Limpar estatísticas de $serverName';
  }

  @override
  String get clearThisServerStats => 'Limpar estatísticas deste servidor';

  @override
  String get compactDatabase => 'Compactar banco de dados';

  @override
  String compactDatabaseContent(Object size) {
    return 'Tamanho do banco de dados: $size\n\nIsso reorganizará o banco de dados para reduzir o tamanho do arquivo. Nenhum dado será excluído.';
  }

  @override
  String get closeAfterSave => 'Salvar e fechar';

  @override
  String get collapseUITip => 'Deve colapsar listas longas na UI por padrão?';

  @override
  String get connectionDetails => 'Detalhes da conexão';

  @override
  String get connectionStats => 'Estatísticas de conexão';

  @override
  String get connectionStatsDesc =>
      'Ver taxa de sucesso de conexão do servidor e histórico';

  @override
  String get containerTrySudoTip =>
      'Por exemplo: se o usuário for definido como aaa dentro do app, mas o Docker estiver instalado sob o usuário root, esta opção precisará ser ativada';

  @override
  String get containerSudoPasswordRequired =>
      'É necessária uma senha sudo para acessar o Docker. Por favor, insira sua senha.';

  @override
  String get containerSudoPasswordIncorrect =>
      'A senha sudo está incorreta ou não é permitida. Por favor, tente novamente.';

  @override
  String get copyPath => 'Copiar caminho';

  @override
  String get cpuViewAsProgressTip =>
      'Exiba a taxa de uso de cada CPU em estilo de barra de progresso (estilo antigo)';

  @override
  String get configured => 'Configured';

  @override
  String get customCmd => 'Comandos personalizados';

  @override
  String get deleteServers => 'Excluir servidores em lote';

  @override
  String get desktopTerminalTip =>
      'Comando usado para abrir o emulador de terminal ao iniciar sessões SSH.';

  @override
  String get dirEmpty => 'Certifique-se de que a pasta está vazia';

  @override
  String get discoverSshServers => 'Descobrir servidores SSH';

  @override
  String get discoveryFailed => 'Descoberta falhou';

  @override
  String get discoverySettings => 'Configurações de descoberta';

  @override
  String get discoverySummary => 'Resumo da descoberta';

  @override
  String get diskHealth => 'Saúde do disco';

  @override
  String get displayCpuIndex => 'Exiba o índice de CPU';

  @override
  String dl2Local(Object fileName) {
    return 'Baixar $fileName para o local?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Não há contêineres em execução.\nIsso pode ser porque:\n- O usuário que instalou o Docker difere do usuário configurado no app\n- A variável de ambiente DOCKER_HOST não foi lida corretamente. Você pode verificar isso executando `echo \$DOCKER_HOST` no terminal.';

  @override
  String dockerImagesFmt(Object count) {
    return 'Total de $count imagens';
  }

  @override
  String get dockerProjectOther => 'Outros';

  @override
  String get dockerPruneTip =>
      'Remova os dados não utilizados para liberar espaço em disco';

  @override
  String get dockerStatistics => 'Estatísticas do Docker';

  @override
  String dockerStatusRunningAndStoppedFmt(
    Object runningCount,
    Object stoppedCount,
  ) {
    return '$runningCount em execução, $stoppedCount parados';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count contêiner(es) em execução';
  }

  @override
  String get doubleColumnMode => 'Modo de coluna dupla';

  @override
  String get doubleColumnTip =>
      'Esta opção apenas ativa a funcionalidade, se ela será ativada depende também da largura do dispositivo';

  @override
  String get editVirtKeys => 'Editar teclas virtuais';

  @override
  String get editorHighlightTip =>
      'O desempenho do destaque de código atualmente é ruim, pode optar por desativá-lo para melhorar.';

  @override
  String get enableMdns => 'Ativar mDNS';

  @override
  String get enableMdnsDesc => 'Usar mDNS/Bonjour para descobrir serviços SSH';

  @override
  String get envVars => 'Variável de ambiente';

  @override
  String get extraArgs => 'Argumentos extras';

  @override
  String get fallbackSshDest => 'Destino SSH de fallback';

  @override
  String get fdroidReleaseTip =>
      'Se você baixou este aplicativo do F-Droid, é recomendado desativar esta opção.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Arquivo \'$file\' muito grande \'$size\', excedendo $sizeMax';
  }

  @override
  String get finishedAt => 'Terminado em';

  @override
  String get followSystem => 'Seguir sistema';

  @override
  String get fontSize => 'Tamanho da fonte';

  @override
  String get fullScreen => 'Modo tela cheia';

  @override
  String get fullScreenJitter => 'Tremulação em tela cheia';

  @override
  String get fullScreenJitterHelp => 'Prevenir burn-in de tela';

  @override
  String get fullScreenTip =>
      'Deve ser ativado o modo de tela cheia quando o dispositivo é girado para o modo paisagem? Esta opção aplica-se apenas à aba do servidor.';

  @override
  String get githubGist => 'GitHub Gist';

  @override
  String get githubGistIdOptional => 'Gist ID (optional)';

  @override
  String get githubGistToken => 'GitHub Gist token';

  @override
  String get githubGistTokenEmpty => 'Token is empty';

  @override
  String get goBackQ => 'Voltar?';

  @override
  String get goto => 'Ir para';

  @override
  String get hideTitleBar => 'Ocultar barra de título';

  @override
  String get highlight => 'Destaque de código';

  @override
  String get homeTabs => 'Abas iniciais';

  @override
  String get homeTabsCustomizeDesc =>
      'Personalize quais abas aparecem na página inicial e sua ordem';

  @override
  String get homeWidgetUrlConfig =>
      'Configuração de URL do widget da tela inicial';

  @override
  String get ignoreCert => 'Ignorar certificado';

  @override
  String get image => 'Imagem';

  @override
  String get imagesList => 'Lista de imagens';

  @override
  String get unused => 'Não utilizado';

  @override
  String get dangling => 'Sem referência';

  @override
  String get pruneUnusedImages => 'Limpar imagens não utilizadas';

  @override
  String get pruneDanglingImages => 'Limpar imagens sem referência';

  @override
  String get pruneImages => 'Limpar imagens';

  @override
  String get unusedTaggedImages => 'Etiquetadas não utilizadas';

  @override
  String get pruneDanglingImagesTip =>
      'Remove apenas imagens sem referência (camadas sem etiqueta).';

  @override
  String get pruneUnusedImagesTip =>
      'Também remove imagens etiquetadas não utilizadas por nenhum contêiner.';

  @override
  String get includeUnusedVolumesTip =>
      'Também remove volumes não utilizados por nenhum contêiner.';

  @override
  String get pruneCommandPreview => 'Pré-visualização do comando';

  @override
  String get pruneForceSshTip =>
      '-f ignora a confirmação interativa e fica sempre ativado na execução por SSH.';

  @override
  String get pruneVolumes => 'Limpar volumes';

  @override
  String get pruneUnusedData => 'Limpar dados não utilizados';

  @override
  String get volume => 'Volume';

  @override
  String get pull => 'Puxar';

  @override
  String get invalid => 'Inválido';

  @override
  String get invalidUrl => 'Invalid URL';

  @override
  String get invalidHostFormat =>
      'Invalid host format. Only IPv4, IPv6, and domain characters are allowed.';

  @override
  String get jumpServer => 'Servidor de salto';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Jump servers not found for $serverName: $jumpIds';
  }

  @override
  String get noJumpServerAvailable => 'No jump server available.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Jump server and ProxyCommand cannot be used together.';

  @override
  String get keepForeground => 'Por favor, mantenha o app em primeiro plano!';

  @override
  String get keepStatusWhenErr => 'Manter o status anterior do servidor';

  @override
  String get keepStatusWhenErrTip => 'Limitado a erros de execução de scripts';

  @override
  String get keyAuth => 'Autenticação por chave';

  @override
  String get lastFailure => 'Última falha';

  @override
  String get lastSuccess => 'Último sucesso';

  @override
  String get letterCache => 'Entrada normal do teclado';

  @override
  String get letterCacheTip =>
      'Quando ativada, a entrada passa pelo IME normal, o que pode evitar avisos de teclado seguro no terminal em alguns sistemas.';

  @override
  String madeWithLove(Object myGithub) {
    return 'Feito com ❤️ por $myGithub';
  }

  @override
  String get maxConcurrency => 'Concorrência máxima';

  @override
  String get maxRetryCount =>
      'Número de tentativas de reconexão com o servidor';

  @override
  String mismatchSystem(Object system) {
    return 'Sistema incompatível: $system';
  }

  @override
  String get more => 'Mais';

  @override
  String get needRestart => 'Necessita reiniciar o app';

  @override
  String get netViewType => 'Tipo de visualização de rede';

  @override
  String get newContainer => 'Novo contêiner';

  @override
  String get noConnectionStatsData => 'Não há dados de estatísticas de conexão';

  @override
  String get noLineChart => 'Não usar gráficos de linha';

  @override
  String get noPrivateKeyTip =>
      'A chave privada não existe, pode ter sido deletada ou há um erro de configuração.';

  @override
  String get noPromptAgain => 'Não perguntar novamente';

  @override
  String get onlyOneLine => 'Exibir apenas como uma linha (rolável)';

  @override
  String get openLastPath => 'Abrir o último caminho';

  @override
  String get openLastPathTip =>
      'Registros diferentes para servidores diferentes, e registra o caminho ao sair';

  @override
  String get parseContainerStatsTip =>
      'Análise de status do Docker pode ser lenta';

  @override
  String get shellSourceNone => 'Sem shell';

  @override
  String get forceSinglePane => 'Coluna única';

  @override
  String get forceSinglePaneTip =>
      'Manter uma coluna independentemente da largura da janela, em vez de mostrar os detalhes ao lado da lista.';

  @override
  String get passwordlessTerminal => 'Terminal sem credenciais';

  @override
  String get passwordlessTerminalTip =>
      'Abrir um terminal através do agente monitor sem credenciais SSH. A shell é executada com a conta com que o agente é executado, por isso basta a palavra-passe do monitor para a obter — a autenticação, o registo e o segundo fator do sshd não se aplicam. É o agente que decide se o permite. Fornece apenas um terminal: SFTP, encaminhamento de portas, contentores, processos e systemd precisam de SSH.';

  @override
  String get passwordlessTerminalNeedsMonitor =>
      'Um terminal sem credenciais requer um endereço de monitor.';

  @override
  String get passwordlessTerminalConflictsWithSsh =>
      'Um terminal sem credenciais não pode ser combinado com credenciais SSH.';

  @override
  String get passwordlessTerminalRefused =>
      'Este agente não oferece um terminal sem credenciais.';

  @override
  String get passwordlessTerminalInsecure =>
      'Este agente serve o terminal apenas por TLS ou loopback, e esta ligação é HTTP não cifrado.';

  @override
  String get permission => 'Permissões';

  @override
  String get plugInType => 'Tipo de Inserção';

  @override
  String get preferDiskAmount => 'Priorizar a exibição da capacidade do disco';

  @override
  String get privateKey => 'Chave privada';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return 'Chave privada [$keyId] não encontrada.';
  }

  @override
  String get pushToken => 'Token de notificação push';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand is only supported on desktop platforms.';

  @override
  String get pveIgnoreCertTip =>
      'Não recomendado para ativar, cuidado com os riscos de segurança! Se estiver usando o certificado padrão do PVE, você precisa habilitar esta opção.';

  @override
  String get pveServerClientMissing =>
      'The SSH client for this server is not available.';

  @override
  String get pveAddressMissing =>
      'The PVE address is missing. Please configure it in server settings.';

  @override
  String get pvePasswordRequired =>
      'PVE password is required. Please set it in server settings.';

  @override
  String get pveOtpRequired =>
      'Two-factor authentication is enabled on this PVE server. Please enter the OTP code.';

  @override
  String get pveOtpChallengeExpired =>
      'The OTP challenge has expired. Please refresh and try again.';

  @override
  String get pveOtpCodeRequired => 'OTP code is required.';

  @override
  String get pveOtpVerificationFailed =>
      'OTP verification failed. Please try again with a fresh code.';

  @override
  String get pveOtpTitle => 'OTP Verification';

  @override
  String get pveOtpLabel => 'OTP Code';

  @override
  String get pveInvalidResponseBody =>
      'PVE login returned an invalid response body.';

  @override
  String get pveInvalidResponseData =>
      'PVE login response did not contain a valid data payload.';

  @override
  String get pveMissingAuthTicket =>
      'PVE login succeeded but no authentication ticket was returned.';

  @override
  String get pveVersionLow =>
      'Esta funcionalidade está atualmente em fase de teste e foi testada apenas no PVE 8+. Por favor, use com cautela.';

  @override
  String get pveLoadingForwarding => 'Establishing SSH tunnel...';

  @override
  String get pveLoadingLogin => 'Authenticating with PVE...';

  @override
  String get pveLoadingData => 'Fetching cluster data...';

  @override
  String get pveLoadingConnect => 'Connecting...';

  @override
  String get pvePassword => 'PVE Password';

  @override
  String get pvePasswordHint =>
      'Required when using key-based SSH authentication';

  @override
  String get read => 'Leitura';

  @override
  String get recentConnections => 'Conexões recentes';

  @override
  String get reconnecting => 'Reconectando...';

  @override
  String get rememberPwdInMem => 'Lembrar senha na memória';

  @override
  String get rememberPwdInMemTip => 'Usado para contêineres, suspensão, etc.';

  @override
  String get remotePath => 'Caminho remoto';

  @override
  String get sameIdServerExist => 'Já existe um servidor com o mesmo ID';

  @override
  String get save => 'Salvar';

  @override
  String get second => 'Segundo';

  @override
  String get serverDetailOrder =>
      'Ordem dos componentes na página de detalhes do servidor';

  @override
  String get serverFuncBtns => 'Botões de função do servidor';

  @override
  String get serverOrder => 'Ordem do servidor';

  @override
  String get serverTabRequired => 'A aba do servidor não pode ser removida';

  @override
  String get shareServerRiskTip =>
      'Este código QR contém as configurações de conexão do servidor em texto simples, incluindo senhas. Qualquer pessoa que o escaneie ou fotografe pode se conectar a este servidor.';

  @override
  String get sftpDlPrepare => 'Preparando para conectar ao servidor...';

  @override
  String get sftpEditorTip =>
      'Se vazio, use o editor de arquivos integrado do aplicativo. Se houver um valor, use o editor do servidor remoto, por exemplo, `vim` (recomendado detectar automaticamente de acordo com `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Usar `rm -r` em SFTP para excluir pastas';

  @override
  String get sftpSSHConnected => 'SFTP conectado...';

  @override
  String get sftp => 'SFTP';

  @override
  String get sftpShowFoldersFirst => 'Mostrar pastas primeiro';

  @override
  String get size => 'Tamanho';

  @override
  String get softWrap => 'Quebra de linha suave';

  @override
  String get specifyDev => 'Especificar dispositivo';

  @override
  String get specifyDevTip =>
      'Por exemplo, as estatísticas de tráfego de rede são por padrão para todos os dispositivos. Você pode especificar um dispositivo específico aqui.';

  @override
  String get tempIsCelsiusTip =>
      'When enabled, the temperature value will be treated as Celsius instead of millicelsius. Turn on only if the temperature displays incorrectly (e.g., showing 0.1°C instead of 58°C).';

  @override
  String get speed => 'Velocidade';

  @override
  String spentTime(Object time) {
    return 'Tempo gasto: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Todos os servidores já existem (encontradas $duplicateCount duplicatas)';
  }

  @override
  String get ssh => 'SSH';

  @override
  String get sshConnectionModeTip =>
      'Built-in: use the app\'s terminal. System SSH: launch the system ssh command in an external terminal.';

  @override
  String get sshConnectionModeUseBuiltin => 'Use built-in terminal';

  @override
  String get sshConnectionModeUseSystem => 'Use system SSH';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount duplicatas serão ignoradas';
  }

  @override
  String get sshConfigFound => 'Encontramos configuração SSH no seu sistema';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return 'Encontrados $totalCount servidores';
  }

  @override
  String get sshConfigImport => 'Importar Configuração SSH';

  @override
  String get sshConfigImportPermission =>
      'Gostaria de dar permissão para ler ~/.ssh/config e importar automaticamente as configurações do servidor?';

  @override
  String get sshConfigImportTip =>
      'Sugestão para ler ~/.ssh/config na criação do primeiro servidor';

  @override
  String sshConfigImported(Object count) {
    return 'Importados $count servidores da configuração SSH';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return 'A chave de host SSH de $serverName foi alterada. Continue apenas se confiar neste servidor.';
  }

  @override
  String sshHostKeyFingerprintMd5Base64(Object fingerprint) {
    return 'Impressão digital (MD5 Base64): $fingerprint';
  }

  @override
  String sshHostKeyFingerprintMd5Hex(Object fingerprint) {
    return 'Impressão digital (MD5 hex): $fingerprint';
  }

  @override
  String get sshHostKeyType => 'Tipo de chave de host SSH';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return 'Uma nova chave de host SSH foi recebida de $serverName. Verifique a impressão digital antes de confiar.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
    return 'Impressão digital armazenada: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Código de verificação';

  @override
  String get sshViaMonitor => 'SSH via monitor';

  @override
  String get sshViaMonitorTip =>
      'Acessa o SSH deste servidor pelo seu agente monitor, para hosts cuja porta SSH não é alcançável diretamente. O agente apenas retransmite bytes: a sessão continua criptografada de ponta a ponta e sua host key continua sendo verificada aqui. O endereço de destino é configurado no agente e não pode ser escolhido pelo app.';

  @override
  String get sshViaMonitorNeedsMonitor =>
      'SSH via monitor requer um endereço de monitor.';

  @override
  String get sshViaMonitorConflictsWithOtherTransport =>
      'SSH via monitor não pode ser combinado com servidor de salto, ProxyCommand ou endereço alternativo.';

  @override
  String get sshConfigManualSelect =>
      'Gostaria de selecionar manualmente o arquivo de configuração SSH?';

  @override
  String get sshConfigNoServers =>
      'Nenhum servidor encontrado na configuração SSH';

  @override
  String get sshConfigPermissionDenied =>
      'Não é possível acessar o arquivo de configuração SSH devido às permissões do macOS.';

  @override
  String sshConfigServersToImport(Object importCount) {
    return '$importCount servidores serão importados';
  }

  @override
  String get sshTermHelp =>
      'Quando o terminal é rolável, arrastar horizontalmente pode selecionar texto. Clicar no botão do teclado ativa/desativa o teclado. O ícone de arquivo abre o SFTP do caminho atual. O botão da área de transferência copia o conteúdo quando o texto é selecionado e cola o conteúdo da área de transferência no terminal quando nenhum texto é selecionado e há conteúdo na área de transferência. O ícone de código cola trechos de código no terminal e os executa.';

  @override
  String get sshVirtualKeyAutoOff =>
      'Desativação automática das teclas virtuais';

  @override
  String get stat => 'Estatísticas';

  @override
  String get supportFmtArgs => 'Suporta os seguintes argumentos formatados:';

  @override
  String get suspendTip =>
      'A função de suspensão requer permissões de root e suporte do systemd.';

  @override
  String switchTo(Object val) {
    return 'Mudar para $val';
  }

  @override
  String get syncAppSettings => 'Sync app settings';

  @override
  String get syncAppSettingsTip =>
      'Include theme, layout, editor, terminal and other device preferences in automatic sync.';

  @override
  String get system => 'Sistema';

  @override
  String get termFontSizeTip =>
      'Esta configuração afetará o tamanho do terminal (largura e altura). Você pode dar zoom na página do terminal para ajustar o tamanho da fonte da sessão atual.';

  @override
  String get textScaler => 'Escala de texto';

  @override
  String get textScalerTip =>
      '1.0 => 100% (tamanho original), afeta apenas algumas fontes na página do servidor, não é recomendado alterar.';

  @override
  String get time => 'Tempo';

  @override
  String get times => 'Vezes';

  @override
  String get trySudo => 'Tentar usar sudo';

  @override
  String get sudoPromptNotFound =>
      'Nenhuma solicitação de senha sudo está ativa.';

  @override
  String get unknown => 'Desconhecido';

  @override
  String get updateServerStatusInterval =>
      'Intervalo de atualização do estado do servidor';

  @override
  String get useNoPwd => 'Será usado sem senha';

  @override
  String get usePodmanByDefault => 'Usar Podman por padrão';

  @override
  String get used => 'Usado';

  @override
  String get view => 'Visualização';

  @override
  String get viewDetails => 'Ver detalhes';

  @override
  String get viewErr => 'Ver erro';

  @override
  String get virtKeyHelpClipboard =>
      'Se houver texto selecionado no terminal, copia para a área de transferência, caso contrário, cola o conteúdo da área de transferência no terminal.';

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
  String get wiki => 'Wiki';

  @override
  String get wolTip =>
      'Após configurar o WOL (Wake-on-LAN), um pedido de WOL é enviado cada vez que o servidor é conectado.';

  @override
  String get write => 'Escrita';

  @override
  String get writeScriptFailTip =>
      'Falha ao escrever no script, possivelmente devido à falta de permissões ou o diretório não existe.';

  @override
  String get writeScriptTip =>
      'Após conectar ao servidor, um script será escrito em `~/.config/server_box` \n | `/tmp/server_box` para monitorar o status do sistema. Você pode revisar o conteúdo do script.';

  @override
  String get menuGitHubRepository => 'GitHub Repository';

  @override
  String get podmanDockerEmulationDetected =>
      'Emulação Podman Docker detectada. Por favor, alterne para Podman nas configurações.';

  @override
  String get portForwardBeta =>
      'This feature is still in beta testing. Functionality is not guaranteed.';

  @override
  String get portForward_startPrompt =>
      'Add a port forward rule to get started';

  @override
  String get portForward_localHost => 'Local Host';

  @override
  String get portForward_localPort => 'Local Port';

  @override
  String get portForward_remoteHost => 'Remote Host';

  @override
  String get portForward_remotePort => 'Remote Port';

  @override
  String get portForward_type_local => 'Local';

  @override
  String get portForward_type_remote => 'Remote';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return 'Delete $name?';
  }

  @override
  String get sponsor => 'Patrocinador';

  @override
  String get sort => 'Sort';

  @override
  String get sortByName => 'By name';

  @override
  String get sortByJoinTime => 'By join time';

  @override
  String get ascending => 'Ascending';

  @override
  String get descending => 'Descending';

  @override
  String get serverHistory => 'Server history';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

  @override
  String get tmuxAutoAttach => 'tmux auto-attach';

  @override
  String get tmuxAuto => 'Auto tmux';

  @override
  String get tmuxAutoTip =>
      'Automatically start or attach tmux when connecting over SSH';

  @override
  String get tmuxSessionSelector => 'Session selector';

  @override
  String get tmuxSessionSelectorTip =>
      'Show the session picker when connecting';

  @override
  String get tmuxDefaultSessionName => 'Default session name';

  @override
  String get tmuxSessionName => 'Session name';

  @override
  String get tmuxExistingSessions => 'Existing sessions';

  @override
  String get tmuxNewSession => 'New session';

  @override
  String get tmuxWindows => 'Windows';

  @override
  String get tmuxNewWindow => 'New window';

  @override
  String get tmuxNoWindowsFound => 'No windows found';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count windows',
      one: '1 window',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count panes',
      one: '1 pane',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Attached';

  @override
  String get tmuxActive => 'Active';

  @override
  String tmuxActiveAt(String time) {
    return 'active: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'attached: $time';
  }

  @override
  String get tmuxSkip => 'Skip';

  @override
  String get tmuxNotAvailable => 'tmux is not available';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Número inesperado de segmentos na resposta do contêiner: $count';
  }

  @override
  String get containerOperationInProgress =>
      'Outra operação de contêiner já está em andamento';

  @override
  String get systemd => 'Systemd';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processos',
      one: '1 processo',
    );
    return '$_temp0';
  }

  @override
  String get processParseUnsupportedOutput =>
      'O formato da lista de processos não é compatível.';

  @override
  String get processParseInvalidRows =>
      'Não foi possível ler algumas entradas de processos.';

  @override
  String get processParseInvalidWindowsJson =>
      'Não foi possível ler a resposta de processos do Windows.';

  @override
  String get processParseInvalidWindowsRows =>
      'Não foi possível ler algumas entradas de processos do Windows.';

  @override
  String get processKillTargetChanged =>
      'O processo foi alterado ou terminou. Atualize a lista e tente novamente.';

  @override
  String get watchServers => 'Servidores no relógio';

  @override
  String get watchServersTip =>
      'O relógio consulta esses servidores diretamente no agente monitor, por isso só é possível escolher servidores com monitor configurado.';

  @override
  String get watchNoMonitorServer =>
      'Nenhum servidor tem um agente monitor configurado';

  @override
  String get watchLegacyUrls => 'URLs de status antigas';

  @override
  String get accessoryWidgetServer => 'Servidor do widget da tela de bloqueio';
}
