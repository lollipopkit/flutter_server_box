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
  String get askAi => 'Perguntar à IA';

  @override
  String get askAiAwaitingResponse => 'Aguardando resposta da IA...';

  @override
  String get askAiEndpointTip =>
      'Informe um URL base do serviço ou um endpoint completo de Chat Completions ou Responses. O ServerBox completa o caminho conforme o protocolo escolhido.';

  @override
  String get askAiProtocolTip =>
      'Automático usa Responses para o endpoint oficial da OpenAI e Chat Completions para provedores compatíveis.';

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
  String get askAiDisclaimer => 'A IA pode errar. Use com cautela.';

  @override
  String get askAiInsertTerminal => 'Inserir no terminal';

  @override
  String get askAiNoResponse => 'Sem resposta';

  @override
  String get askAiAgentTitle => 'Agente SSH';

  @override
  String get askAiAgentWelcome => 'O que vamos fazer neste servidor?';

  @override
  String get askAiAgentWelcomeTip =>
      'Peça um diagnóstico ou uma tarefa. O Agente propõe um comando de cada vez e aguarda sua revisão antes de alterar algo.';

  @override
  String get askAiAgentPromptHint =>
      'Peça ao Agente para inspecionar ou corrigir algo...';

  @override
  String get askAiAgentSend => 'Enviar ao Agente';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analise o conteúdo selecionado do terminal, explique o que aconteceu e proponha o próximo passo mais seguro se for preciso agir.';

  @override
  String get askAiTerminalContext => 'Contexto do terminal';

  @override
  String get askAiReviewNeeded => 'Revisar';

  @override
  String get askAiReviewAction => 'Revisar o comando proposto';

  @override
  String get askAiReviewBeforeContinuing =>
      'Revise ou recuse primeiro o comando proposto';

  @override
  String get askAiApproveRun => 'Aprovar e executar';

  @override
  String get askAiDecline => 'Recusar';

  @override
  String get askAiActionDeclined => 'O comando proposto foi recusado.';

  @override
  String get askAiInterrupted => 'A resposta do Agente foi interrompida.';

  @override
  String get askAiRiskReadOnly => 'Somente leitura';

  @override
  String get askAiRiskCaution => 'Altera o sistema';

  @override
  String get askAiRiskUnvetted => 'Host não verificado';

  @override
  String get askAiRiskDestructive => 'Alto risco';

  @override
  String get askAiHighRiskConfirmTitle => 'Executar comando de alto risco?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Este comando pode apagar dados, parar serviços ou ser difícil de desfazer. Revise com atenção antes de executar.';

  @override
  String get askAiNoCommandOutput => 'O comando terminou sem saída.';

  @override
  String get askAiOutputTruncated =>
      'A saída longa foi truncada antes de voltar para o Agente.';

  @override
  String get askAiAutoApproved => 'Aprovado automaticamente';

  @override
  String get askAiAutoRunSafeCommands =>
      'Executar automaticamente comandos somente leitura';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Só executa automaticamente quando o modelo e as verificações locais de segurança classificam o comando como somente leitura. Comandos que alteram o sistema continuam exigindo revisão.';

  @override
  String get askAiSendOnEnter => 'Enter envia';

  @override
  String get askAiSendOnEnterTip =>
      'Enter envia a mensagem e Shift+Enter quebra a linha. Desligado, inverte: Enter quebra a linha e Cmd/Ctrl+Enter envia.';

  @override
  String get askAiApiKeyOptional =>
      'Opcional para endpoints locais ou sem autenticação';

  @override
  String get askAiHistory => 'Histórico de conversas';

  @override
  String get askAiNewConversation => 'Nova conversa';

  @override
  String get askAiNoHistory => 'Nenhuma conversa salva para este servidor';

  @override
  String get askAiNoHistoryMessages => 'Ainda sem mensagens';

  @override
  String get askAiUntitledConversation => 'Nova conversa';

  @override
  String get askAiRenameConversation => 'Renomear conversa';

  @override
  String get askAiDeleteConversationTitle => 'Excluir esta conversa?';

  @override
  String get askAiDeleteConversationTip =>
      'A conversa será removida deste dispositivo e não poderá ser recuperada.';

  @override
  String get askAiClearHistoryTitle =>
      'Limpar o histórico do Agente deste servidor?';

  @override
  String get askAiClearHistoryTip =>
      'Todas as conversas do Agente salvas para este servidor serão removidas deste dispositivo.';

  @override
  String get askAiRestoredReview =>
      'Restaurado do histórico. Revise novamente antes de executar; ele nunca será executado sozinho.';

  @override
  String get agentTitle => 'Agente';

  @override
  String get agentWelcome => 'O que vamos fazer nos seus servidores?';

  @override
  String get agentWelcomeTip =>
      'Peça um diagnóstico ou uma tarefa operacional. O Agente usa o estado atual do ServerBox e propõe uma ação revisada de cada vez.';

  @override
  String get agentPromptHint =>
      'Peça ao Agente para inspecionar ou operar seus servidores...';

  @override
  String get agentNoHistory => 'Nenhuma conversa global do Agente salva';

  @override
  String get agentClearHistoryTitle => 'Limpar o histórico global do Agente?';

  @override
  String get agentClearHistoryTip =>
      'Todas as conversas globais do Agente serão removidas deste dispositivo.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Ler arquivo';

  @override
  String get agentToolWriteFile => 'Gravar arquivo';

  @override
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => 'Falha ao executar a ferramenta.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count chamadas de ferramenta';
  }

  @override
  String get agentFloat => 'Flutuar sobre as outras abas';

  @override
  String get agentToolSshConnect => 'Conectar por SSH';

  @override
  String get agentToolSshDisconnect => 'Desconectar SSH';

  @override
  String get agentSshConnectTitle => 'Conectar a um novo host';

  @override
  String get agentAuthMethod => 'Autenticação';

  @override
  String get agentSshConnectTip =>
      'O Agente quer abrir uma conexão SSH. Digite a senha aqui, nunca na conversa, onde ela ficaria salva e seria enviada ao modelo.';

  @override
  String get agentAdHocSessions => 'Conexões temporárias';

  @override
  String get agentSaveServerTitle => 'Salvar como servidor';

  @override
  String get agentSaveServerTip =>
      'Este host e a senha digitada serão salvos neste dispositivo.';

  @override
  String get agentMonitorOptional => 'Agente monitor (opcional)';

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
  String get remoteBackupPasswordRequired =>
      'Remote backups require a non-empty backup password';

  @override
  String get monitorHttpsRequired =>
      'Remote monitor agents require HTTPS; HTTP is allowed only on loopback.';

  @override
  String get monitorAllowInsecureHttp => 'Allow insecure HTTP';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Only enable for a trusted private network with transport encryption outside HTTP, such as Tailscale. The agent must also explicitly allow plaintext file access. Credentials and file contents may otherwise be exposed.';

  @override
  String get backupTip =>
      'Os dados exportados podem ser criptografados com senha. \nPor favor, guarde-os com segurança.';

  @override
  String get icloudBackupStatusTitle => 'Estado do backup';

  @override
  String get icloudBackupStatusLoading =>
      'Carregando o estado do backup do iCloud...';

  @override
  String get icloudBackupStatusError =>
      'Não foi possível ler os metadados do backup do iCloud';

  @override
  String get icloudBackupStatusEmpty =>
      'Nenhum arquivo de backup do iCloud encontrado ainda';

  @override
  String get icloudBackupStateUploading => 'Enviando';

  @override
  String get icloudBackupStateConflict => 'Conflito detectado';

  @override
  String get icloudBackupStateUploaded => 'Enviado';

  @override
  String get icloudBackupStateWaiting => 'Aguardando o iCloud';

  @override
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Último backup: $lastModified\nEstado: $remoteState';
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
  String get customCmd => 'Comandos personalizados';

  @override
  String get deleteServers => 'Excluir servidores em lote';

  @override
  String get deleteDirRecursive => 'Eliminar a pasta e todo o seu conteúdo';

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
  String get distro => 'Distribuição';

  @override
  String distroSwitchTip(Object from, Object to) {
    return 'Substituir $from por $to. Tudo o que foi instalado dentro de $from é eliminado e, no seu lugar, $to é transferido e descompactado.';
  }

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
  String get doubleColumnMode => 'Modo de coluna dupla';

  @override
  String get doubleColumnTip =>
      'Esta opção apenas ativa a funcionalidade, se ela será ativada depende também da largura do dispositivo';

  @override
  String get editVirtKeys => 'Teclas virtuais';

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
  String get fileDirGone => 'Esta pasta já não está aqui';

  @override
  String get fileDirGoneTip =>
      'Foi eliminada ou renomeada. Use a barra abaixo para voltar, ir para a pasta inicial ou saltar para outro local.';

  @override
  String get fullScreen => 'Tela cheia';

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
  String get githubGistIdOptional => 'ID do Gist (opcional)';

  @override
  String get githubGistToken => 'Token do GitHub Gist';

  @override
  String get githubGistTokenEmpty => 'O token está vazio';

  @override
  String get goto => 'Ir para';

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
  String get macDmgBody =>
      'A App Store exige que este app rode em sandbox, e um processo em sandbox não consegue abrir um pseudoterminal. Por isso a versão da App Store não tem terminal neste Mac e não executa aqui um snippet ou um comando do agente. A versão DMG é o mesmo app assinado sem sandbox, e tem os dois.\n\nA versão da App Store continua funcionando e continua recebendo atualizações. Mais adiante isso pode terminar.\n\nAs duas versões guardam os dados em lugares diferentes. A versão DMG os copia na primeira abertura, então servidores, chaves e histórico vão junto. Se falhar, ela avisa, e você pode migrar com um arquivo de backup (Backup, nos ajustes).';

  @override
  String get macDmgImportDenied =>
      'O macOS não permitiu ler os dados da versão instalada anteriormente. Conceda Acesso Total ao Disco e reabra o app, ou exporte um backup lá e restaure-o aqui.';

  @override
  String get macDmgImported =>
      'Dados da versão instalada anteriormente importados.';

  @override
  String get macDmgImportFailed =>
      'Não foi possível ler os dados da versão instalada anteriormente. Exporte um backup lá e restaure-o aqui.';

  @override
  String get macDmgTip =>
      'O terminal neste Mac e executar snippets nele só existem na versão DMG.';

  @override
  String get macDmgTitle => 'Versão DMG';

  @override
  String get showHiddenFiles => 'Mostrar ficheiros ocultos';

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
  String get pull => 'Puxar';

  @override
  String get invalidHostFormat =>
      'Formato de host inválido. São permitidos apenas caracteres de IPv4, IPv6 e domínio.';

  @override
  String get jumpServer => 'Servidor de salto';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Servidores de salto não encontrados para $serverName: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
    return '\"$name\" já existe';
  }

  @override
  String get noJumpServerAvailable => 'Nenhum servidor de salto disponível.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Servidor de salto e ProxyCommand não podem ser usados juntos.';

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
  String get linuxShellTip =>
      'O que um terminal interativo executa. O Alpine não tem chsh e nada no sistema lê /etc/passwd, por isso só isto decide. Comandos avulsos continuam a correr com /bin/sh, porque a app e o Agent escrevem POSIX. Deixe vazio para restaurar /bin/sh.';

  @override
  String get linuxNetTip =>
      'De onde o sistema Linux e os seus pacotes são transferidos, e os servidores DNS escritos nele. Deixe vazio para restaurar o padrão. Ao guardar, ambos são reescritos também num sistema já instalado.';

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
  String get mirror => 'Espelho';

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
  String get bmcPowerOnAction => 'Ligar';

  @override
  String get bmcShutdown => 'Desligar';

  @override
  String get bmcForceOff => 'Forçar desligamento';

  @override
  String get bmcRestart => 'Reiniciar';

  @override
  String get bmcPowerCycle => 'Ciclo de energia';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'Enviar isto para $server? Será pedido ao serviço \"$resetType\", que é o que ele permite para esta ação.';
  }

  @override
  String get bmcPowerDone => 'O estado de energia mudou';

  @override
  String get bmcPowerAccepted =>
      'Aceite, mas o estado de energia ainda não mudou. Uma operação limpa depende do sistema operativo, e alguns serviços não a distinguem.';

  @override
  String get bmcPowerUnsupported =>
      'Este serviço não permite nada para essa ação';

  @override
  String get bmcUnauthorized => 'O BMC recusou a conta';

  @override
  String get bmcPowerOn => 'Ligado';

  @override
  String get bmcPowerOff => 'Desligado';

  @override
  String get bmcCertRejected =>
      'Certificado recusado — verifique-o nas definições do servidor';

  @override
  String get bmcNotAService => 'Não há serviço Redfish neste endereço';

  @override
  String get bmcNoSystem => 'O serviço não reporta qualquer sistema';

  @override
  String get bmcSensorsTruncated => 'Só são mostrados os primeiros sensores';

  @override
  String get bmcTip =>
      'O BMC é um computador à parte na placa principal, alcançável quando o sistema operativo do anfitrião não está. Configurado aqui, reporta o estado de energia e os sensores de hardware enquanto o servidor está desligado ou bloqueado. Requer Redfish, presente na maioria do hardware empresarial desde cerca de 2016.';

  @override
  String get bmcCert => 'Certificado';

  @override
  String get bmcCertPinned => 'Verificado e fixado';

  @override
  String get bmcCertUnreviewed =>
      'Ainda não verificado — toque para ver o que o BMC apresenta';

  @override
  String get bmcCertReview =>
      'Os BMC usam certificados autoassinados, por isso nada abona este. Compare-o com o que a própria interface web do BMC mostra. Depois de aceite, apenas este certificado exato é considerado fidedigno.';

  @override
  String get bmcCertChanged =>
      'Este não é o certificado aceite anteriormente. Acontece quando o BMC regenera o certificado ou o firmware é atualizado — mas é também o aspeto que teria uma interceção. Verifique antes de aceitar.';

  @override
  String get bmcCertExpired =>
      'Este certificado está fora das suas datas de validade.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Aceite anteriormente: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'O endereço do BMC tem de ser um URL, p. ex. https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Esta compilação corre numa sandbox: o comando vê uma pasta pessoal vazia em vez da sua, por isso tudo o que leia ~/.ssh (ssh -W, cloudflared) falha, muitas vezes como um tempo limite que indica o anfitrião errado. Comandos que só usam a rede continuam a funcionar. A versão DMG não tem sandbox.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'Não é possível ler o ficheiro de chave privada $path: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'Esta compilação não consegue ler ficheiros fora do seu contentor, por isso a chave em $path está inacessível. Importe a chave nas definições ou use a versão DMG.';
  }

  @override
  String get pushToken => 'Token de notificação push';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand só é suportado em plataformas desktop.';

  @override
  String get pveIgnoreCertTip =>
      'Não recomendado para ativar, cuidado com os riscos de segurança! Se estiver usando o certificado padrão do PVE, você precisa habilitar esta opção.';

  @override
  String get pveServerClientMissing =>
      'O cliente SSH deste servidor não está disponível.';

  @override
  String get pveAddressMissing =>
      'Falta o endereço do PVE. Configure-o nas configurações do servidor.';

  @override
  String get pvePasswordRequired =>
      'A senha do PVE é obrigatória. Defina-a nas configurações do servidor.';

  @override
  String get pveOtpRequired =>
      'A autenticação em duas etapas está ativa neste servidor PVE. Informe o código OTP.';

  @override
  String get pveOtpChallengeExpired =>
      'O desafio OTP expirou. Atualize e tente novamente.';

  @override
  String get pveOtpCodeRequired => 'O código OTP é obrigatório.';

  @override
  String get pveOtpVerificationFailed =>
      'Falha na verificação do OTP. Tente novamente com um código novo.';

  @override
  String get pveOtpTitle => 'Verificação OTP';

  @override
  String get pveOtpLabel => 'Código OTP';

  @override
  String get pveInvalidResponseBody =>
      'O login do PVE retornou um corpo de resposta inválido.';

  @override
  String get pveInvalidResponseData =>
      'A resposta do login do PVE não continha dados válidos.';

  @override
  String get pveMissingAuthTicket =>
      'O login do PVE funcionou, mas nenhum ticket de autenticação foi retornado.';

  @override
  String get pveVersionLow =>
      'Esta funcionalidade está atualmente em fase de teste e foi testada apenas no PVE 8+. Por favor, use com cautela.';

  @override
  String get pveLoadingForwarding => 'Estabelecendo o túnel SSH...';

  @override
  String get pveLoadingLogin => 'Autenticando no PVE...';

  @override
  String get pveLoadingData => 'Buscando dados do cluster...';

  @override
  String get pveLoadingConnect => 'Conectando...';

  @override
  String get pvePassword => 'Senha do PVE';

  @override
  String get pvePasswordHint => 'Necessária ao usar autenticação SSH por chave';

  @override
  String get read => 'Leitura';

  @override
  String get recentConnections => 'Conexões recentes';

  @override
  String get rememberPwdInMem => 'Lembrar senha na memória';

  @override
  String get rememberPwdInMemTip => 'Usado para contêineres, suspensão, etc.';

  @override
  String get remotePath => 'Caminho remoto';

  @override
  String rootfsUpdateTip(
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return 'O $distro $installed está instalado e o $latest está disponível. Atualizar baixa tudo de novo e substitui o contêiner: perde-se tudo o que foi instalado dentro dele com o $pm. Se você pular, o atual continua funcionando.';
  }

  @override
  String linuxSystemInUse(Object name) {
    return 'O $name ainda tem um terminal aberto. Feche-o antes de excluir o sistema.';
  }

  @override
  String get rootfsSubtitle => 'Um espaço de usuário Linux neste dispositivo';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
    return 'Baixa o $distro $version (cerca de $size MB) e o descompacta neste dispositivo. Dá a este app um shell com gerenciador de pacotes, e pode ser excluído a qualquer momento.';
  }

  @override
  String get sameIdServerExist => 'Já existe um servidor com o mesmo ID';

  @override
  String get second => 'Segundo';

  @override
  String get serverFilesUnavailableTip =>
      'Acessível através do SSH deste servidor, ou através de um agente monitor com a sua API de ficheiros ativada.';

  @override
  String get back => 'Voltar';

  @override
  String get history => 'Histórico';

  @override
  String get homeDir => 'Pasta pessoal';

  @override
  String get selectItem => 'Selecionar';

  @override
  String selected(Object count) {
    return '$count selecionados';
  }

  @override
  String get sendTo => 'Enviar para…';

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
  String get specifyDev => 'Especificar dispositivo';

  @override
  String get specifyDevTip =>
      'Por exemplo, as estatísticas de tráfego de rede são por padrão para todos os dispositivos. Você pode especificar um dispositivo específico aqui.';

  @override
  String get tempIsCelsiusTip =>
      'Quando ativado, o valor de temperatura é tratado como Celsius em vez de milicelsius. Ative apenas se a temperatura aparecer errada (por exemplo, 0,1 °C em vez de 58 °C).';

  @override
  String spentTime(Object time) {
    return 'Tempo gasto: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Todos os servidores já existem (encontradas $duplicateCount duplicatas)';
  }

  @override
  String get sshConnectionModeTip =>
      'Integrado: usar o terminal do app. SSH do sistema: iniciar o comando ssh do sistema em um terminal externo.';

  @override
  String get sshConnectionModeUseBuiltin => 'Usar o terminal integrado';

  @override
  String get sshConnectionModeUseSystem => 'Usar o SSH do sistema';

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
    return 'Impressão digital (SHA256): $fingerprint';
  }

  @override
  String get sshHostKeyType => 'Tipo de chave de host SSH';

  @override
  String get sshKnownHostKeys => 'Anfitriões conhecidos';

  @override
  String get sshKnownHostKeysTip =>
      'Chaves de anfitrião que esta app aceitou. Elimine uma para voltar a ser questionado na próxima ligação.';

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
  String get supportFmtArgs => 'Suporta os seguintes argumentos formatados:';

  @override
  String get suspendTip =>
      'A função de suspensão requer permissões de root e suporte do systemd.';

  @override
  String switchTo(Object val) {
    return 'Mudar para $val';
  }

  @override
  String get syncAppSettings => 'Sincronizar as configurações do app';

  @override
  String get syncAppSettingsTip =>
      'Incluir tema, layout, editor, terminal e outras preferências do dispositivo na sincronização automática.';

  @override
  String get system => 'Sistema';

  @override
  String get termFontSizeTip =>
      'Esta configuração afetará o tamanho do terminal (largura e altura). Você pode dar zoom na página do terminal para ajustar o tamanho da fonte da sessão atual.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (tamanho original), afeta apenas algumas fontes na página do servidor, não é recomendado alterar.';

  @override
  String get times => 'Vezes';

  @override
  String get trySudo => 'Tentar usar sudo';

  @override
  String get sudoPromptNotFound =>
      'Nenhuma solicitação de senha sudo está ativa.';

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
  String get virtKeyHelpClipboard =>
      'Se houver texto selecionado no terminal, copia para a área de transferência, caso contrário, cola o conteúdo da área de transferência no terminal.';

  @override
  String get virtKeyHelpIME => 'Ligar/desligar o teclado';

  @override
  String get virtKeyHelpSFTP => 'Abre o caminho atual em SFTP.';

  @override
  String get virtKeyHelpSnippet =>
      'Escolha um trecho e execute-o neste terminal.';

  @override
  String get virtKeyHelpTmux => 'Alterne entre sessões e janelas do tmux.';

  @override
  String get virtKeyIntroActions => 'Atalhos';

  @override
  String get virtKeyIntroActionsTip =>
      'Estas teclas não escrevem, abrem algo. Mantenha uma pressionada para ler o que ela faz.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'Nas configurações do terminal você pode reordená-las ou ocultar as que nunca usa.';

  @override
  String get virtKeyIntroModifiers => 'Modificadores';

  @override
  String get virtKeyIntroModifiersTip =>
      'Toque em uma para ativá-la e depois em uma letra do teclado. Vale só para essa tecla.';

  @override
  String get virtKeyIntroNav => 'Navegação';

  @override
  String get virtKeyIntroNavTip =>
      'Estas teclas movem o cursor. Mantenha uma seta pressionada para repeti-la.';

  @override
  String get virtKeyIntroSelect =>
      'Enquanto o terminal tiver algo a rolar, arraste na horizontal para selecionar texto.';

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
  String get menuGitHubRepository => 'Repositório no GitHub';

  @override
  String get podmanDockerEmulationDetected =>
      'Emulação Podman Docker detectada. Por favor, alterne para Podman nas configurações.';

  @override
  String get betaTip =>
      'Este recurso ainda está em beta. O funcionamento não é garantido.';

  @override
  String get portForward_startPrompt =>
      'Adicione uma regra de encaminhamento de porta para começar';

  @override
  String get portForward_localHost => 'Host local';

  @override
  String get portForward_localPort => 'Porta local';

  @override
  String get portForward_remoteHost => 'Host remoto';

  @override
  String get portForward_remotePort => 'Porta remota';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return 'Excluir $name?';
  }

  @override
  String get sponsor => 'Patrocinador';

  @override
  String get sortByJoinTime => 'Por data de adição';

  @override
  String get serverHistory => 'Histórico do servidor';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

  @override
  String get tmuxAutoAttach => 'Anexar ao tmux automaticamente';

  @override
  String get tmuxAuto => 'tmux automático';

  @override
  String get tmuxAutoTip =>
      'Iniciar ou anexar o tmux automaticamente ao conectar por SSH';

  @override
  String get tmuxSessionSelector => 'Seletor de sessão';

  @override
  String get tmuxSessionSelectorTip =>
      'Mostrar o seletor de sessão ao conectar';

  @override
  String get tmuxDefaultSessionName => 'Nome de sessão padrão';

  @override
  String get tmuxSessionName => 'Nome da sessão';

  @override
  String get tmuxExistingSessions => 'Sessões existentes';

  @override
  String get tmuxNewSession => 'Nova sessão';

  @override
  String get tmuxWindows => 'Janelas';

  @override
  String get tmuxNewWindow => 'Nova janela';

  @override
  String get tmuxNoWindowsFound => 'Nenhuma janela encontrada';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count janelas',
      one: '1 janela',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count painéis',
      one: '1 painel',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Anexada';

  @override
  String get tmuxActive => 'Ativa';

  @override
  String tmuxActiveAt(String time) {
    return 'ativa: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'anexada: $time';
  }

  @override
  String get tmuxSkip => 'Pular';

  @override
  String get tmuxNotAvailable => 'o tmux não está disponível';

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

  @override
  String get systemdMissing => 'Sem systemd neste servidor';

  @override
  String get systemdMissingTip =>
      '`systemctl` não está instalado aqui, portanto não há units para listar.';

  @override
  String initSystemFmt(String init) {
    return 'Esta máquina parece usar $init.';
  }

  @override
  String get systemdListFailed => 'Não foi possível listar as units';

  @override
  String get systemdUserScopeMissing => 'As units de usuário não são listadas';

  @override
  String get systemdUserScopeMissingTip =>
      'Esta conta não tem barramento de sessão de usuário no servidor, então apenas as units do sistema são exibidas.';

  @override
  String get serverUnreachable =>
      'Não foi possível executar um comando neste servidor';

  @override
  String get containerNoRuntime => 'Nenhum runtime de contêiner aqui';

  @override
  String get containerNoRuntimeTip =>
      'Nem `docker` nem `podman` responderam nesta máquina. Se um deles estiver instalado para outra conta, ative \"Tentar usar sudo\" nas configurações.';

  @override
  String get containerUnreadable =>
      'O runtime de contêiner respondeu em um formato inesperado';

  @override
  String get power => 'Energia';

  @override
  String get continueInTerminal => 'Continuar no terminal';

  @override
  String get askAiRiskUnknown => 'Não classificado';

  @override
  String get agentLocalExec => 'Executar comandos neste dispositivo';

  @override
  String get agentLocalExecTip =>
      'Permite que o Agent trabalhe na máquina onde o ServerBox está a ser executado, não apenas em servidores. Aqui nada corre sem supervisão: todos os comandos precisam de revisão.';

  @override
  String get agentLocalExecRootfsTip =>
      'Permite que o Agent trabalhe neste dispositivo, dentro do contêiner Alpine Linux que o ServerBox instala. Ele não consegue ver o sistema de arquivos do telefone, os dados do app nem os seus arquivos. Todos os comandos continuam precisando de revisão.';

  @override
  String macDmgImportedPartly(String path) {
    return 'Os dados da versão instalada anteriormente foram importados. Os ficheiros transferidos ficaram em $path.';
  }

  @override
  String get bmcAccount => 'Conta';

  @override
  String get bmcAccountUnset =>
      'Nenhuma selecionada — toque para escolher ou criar uma';

  @override
  String bmcAccountShared(int count) {
    return 'Usada por $count servidores';
  }

  @override
  String get bmcAccounts => 'Contas de BMC';

  @override
  String get bmcAccountSharedTip => 'Editá-la muda o que todos eles usam.';

  @override
  String bmcAccountInUse(int count) {
    return '$count servidores a usam. Mantêm o endereço e perdem a conta.';
  }
}
