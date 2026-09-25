// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appearanceSettings => 'Aparência';

  @override
  String get appearancePreset => 'Tema predefinido';

  @override
  String get appearanceThemeSchemaRange => 'Schema de tema compatível';

  @override
  String get appearanceThemeInstall => 'Instalar tema';

  @override
  String get appearanceThemeStore => 'Loja de temas';

  @override
  String get appearanceInvalidTheme => 'Pacote de tema ou catálogo inválido';

  @override
  String get themeStoreRefreshFailed =>
      'Não foi possível ler o catálogo de temas.';

  @override
  String themeStoreDeleteTheme(String name) {
    return 'Excluir «$name»? Seus arquivos são removidos deste dispositivo. Se for o tema em uso, o app volta ao tema padrão.';
  }

  @override
  String themeStoreUpdatedFmt(String ago) {
    return 'atualizado $ago';
  }

  @override
  String get themeStoreUpdatedJustNow => 'atualizado agora mesmo';

  @override
  String get themeStoreSortInUse => 'Em uso primeiro';

  @override
  String themeStoreMakeOwnFmt(String doc) {
    return 'Quer criar seu próprio tema? Veja [como criar um]($doc) — obrigado pela sua contribuição!';
  }

  @override
  String appearanceThemeNeedsNewerApp(String version) {
    return 'É necessário usar uma versão mais recente do app: $version';
  }

  @override
  String get appearanceFontFamilies => 'Famílias de fontes da interface';

  @override
  String get appearanceFontFamiliesTip =>
      'Um nome por linha; as fontes são testadas pela ordem.';

  @override
  String get appearanceFontImport => 'Importar arquivo de fonte da interface';

  @override
  String get appearanceGradient => 'Gradiente';

  @override
  String get appearanceNoBackground => 'Sem plano de fundo';

  @override
  String get appearanceIcons => 'Ícones no app';

  @override
  String get appearanceCorners => 'Cantos';

  @override
  String get appearanceCardCorners => 'Cantos dos cartões';

  @override
  String get appearanceTileCorners => 'Cantos dos itens';

  @override
  String get appearanceButtonCorners => 'Cantos dos botões';

  @override
  String get crashCollect => 'Dados de diagnóstico';

  @override
  String get crashCollectIntro =>
      'O ServerBox registra o que acontece durante a execução para que os problemas possam ser corrigidos. Escolha quanta informação enviar.';

  @override
  String get crashCollectNone => 'Nada';

  @override
  String get crashCollectNoneTip =>
      'Os relatórios continuam neste dispositivo; após uma falha, você pode enviar um manualmente.';

  @override
  String get crashCollectBasic => 'Informações básicas';

  @override
  String get crashCollectBasicTip =>
      'Inclui apenas informações sobre a falha; não inclui registros nem dados de desempenho. **Isso nos ajuda a melhorar o app e corrigir bugs.**';

  @override
  String get crashCollectFull => 'Informações completas';

  @override
  String get crashCollectFullTip =>
      'Além do registro da falha, inclui dados de desempenho e o uso de funcionalidades: servem para localizar o que está lento e quais funcionalidades são realmente usadas.';

  @override
  String get crashCollectFooter =>
      'Em todos os níveis, nomes de servidor conhecidos, seus endereços e nomes de usuário são substituídos por marcadores no momento do registro. Você pode alterar o nível de coleta mais tarde nas configurações.';

  @override
  String get privacy => 'Privacidade';

  @override
  String get privacyPolicy => 'Política de privacidade';

  @override
  String get crashLastRunFailed =>
      'O ServerBox fechou inesperadamente durante a última execução.';

  @override
  String get crashReportTitle => 'Relatório de falha';

  @override
  String get crashReportHint =>
      'Este é o registro da execução anterior. Nomes e endereços de servidor conhecidos foram substituídos por marcadores, mas outros detalhes podem permanecer. Leia-o com atenção antes de enviá-lo.';

  @override
  String get crashReportSubmit => 'Copiar e relatar';

  @override
  String get preReleaseUpdates => 'Receber atualizações de pré-lançamento';

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
      'Um domínio ou um URL completo. O caminho é completado pelo protocolo escolhido.';

  @override
  String get askAiProtocolTip =>
      'Auto tenta Responses e depois Chat Completions.';

  @override
  String get askAiCommandInserted => 'Comando inserido no terminal';

  @override
  String askAiConfigMissing(String fields) {
    return 'Configure $fields nas configurações.';
  }

  @override
  String get askAiDisclaimer => 'A IA pode errar. Use com cautela.';

  @override
  String get askAiInsertTerminal => 'Inserir no terminal';

  @override
  String get askAiNoResponse => 'Sem resposta';

  @override
  String get remoteDesktop => 'Área de trabalho remota';

  @override
  String get askAiAgentWelcome => 'O que vamos fazer neste servidor?';

  @override
  String get askAiAgentPromptHint =>
      'Peça ao Agente para inspecionar ou corrigir algo...';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analise a saída selecionada do terminal e explique o que aconteceu';

  @override
  String get askAiTerminalContext => 'Contexto do terminal';

  @override
  String get askAiReviewNeeded => 'Revisar';

  @override
  String get askAiReviewAction => 'Revisar o comando proposto';

  @override
  String get askAiReviewBeforeContinuing =>
      'Reveja ou recuse a sugestão atual primeiro';

  @override
  String get askAiApproveRun => 'Aprovar e executar';

  @override
  String get askAiDecline => 'Recusar';

  @override
  String get askAiActionDeclined => 'O comando proposto foi recusado.';

  @override
  String get askAiInterrupted => 'A resposta do Agente foi interrompida.';

  @override
  String get askAiResend => 'Reenviar';

  @override
  String get askAiResendTip =>
      'Tudo após esta mensagem será descartado — as respostas, os comandos e seus resultados.';

  @override
  String get askAiDeleteTip =>
      'Esta mensagem e tudo após ela serão removidos — as respostas, os comandos e seus resultados.';

  @override
  String get askAiModelTable => 'Tabela de modelos';

  @override
  String get askAiModelTableTip =>
      'Tamanhos de contexto por nome de modelo, fornecidos por models.dev. Uma tabela vem com o app; toque para baixar uma versão mais recente.';

  @override
  String get askAiContextFallback => 'não consta na tabela';

  @override
  String get askAiCompactAt => 'Resumir em';

  @override
  String get askAiCompactAtTip =>
      'Quanto o contexto do modelo pode ser preenchido antes que as interações anteriores sejam resumidas. Um valor menor perde detalhes mais cedo; um valor maior aumenta o risco de o modelo recusar uma solicitação.';

  @override
  String get askAiContextTokens => 'Tamanho do contexto';

  @override
  String get askAiContextTokensTip =>
      'Quantos tokens este modelo comporta. O modo automático procura pelo nome; informe um número quando o provedor oferecer uma janela menor que a capacidade do modelo.';

  @override
  String get askAiConversationCompacted =>
      'As mensagens anteriores foram resumidas para permitir que a conversa continuasse.';

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
      'Este comando pode fazer alterações difíceis de desfazer. Verifique com cuidado.';

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
      'Só executa se o modelo e a verificação local o considerarem só de leitura';

  @override
  String get askAiSendOnEnter => 'Enter envia';

  @override
  String get askAiSendOnEnterTip =>
      'Enter envia, Shift+Enter nova linha. Desligado: Enter nova linha, Cmd/Ctrl+Enter envia.';

  @override
  String get askAiApiKeyOptional =>
      'Deixe vazio para local ou sem autenticação';

  @override
  String get askAiAllowInsecure => 'Permitir HTTP simples';

  @override
  String get askAiAllowInsecureTip =>
      'Permite conexões http:// a modelos auto-hospedados em endereços diferentes de localhost. A chave da API e qualquer contexto do terminal serão enviados sem criptografia; localhost não é afetado.';

  @override
  String get askAiInsecureEndpoint =>
      'Este endpoint usa http://. Ative “Permitir HTTP simples” nas configurações de AI para usá-lo.';

  @override
  String get askAiHistory => 'Histórico de conversas';

  @override
  String get askAiNewConversation => 'Nova conversa';

  @override
  String get askAiNoHistory => 'Ainda sem conversas guardadas';

  @override
  String get askAiNoHistoryMessages => 'Ainda sem mensagens';

  @override
  String get askAiUntitledConversation => 'Sem título';

  @override
  String get askAiRenameConversation => 'Renomear conversa';

  @override
  String get askAiDeleteConversationTitle => 'Excluir esta conversa?';

  @override
  String get askAiDeleteConversationTip =>
      'Apaga-a deste dispositivo. Não pode ser desfeito.';

  @override
  String get askAiClearHistoryTitle =>
      'Limpar o histórico do Agente deste servidor?';

  @override
  String get askAiClearHistoryTip =>
      'Todas as conversas do Agent guardadas deste servidor serão apagadas.';

  @override
  String get askAiRestoredReview => 'Este comando vem do histórico. Reveja-o';

  @override
  String get agentWelcome => 'O que vamos fazer nos seus servidores?';

  @override
  String get agentWelcomeTip =>
      'Deixe o Agent diagnosticar um problema ou executar uma tarefa';

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
  String get agentToolFailed => 'Falha ao executar a ferramenta.';

  @override
  String agentToolCallsFmt(int count) {
    return '$count chamadas de ferramenta';
  }

  @override
  String get floatOverTabs => 'Flutuar sobre as outras abas';

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
      'O Agent quer uma ligação SSH. Escreva a palavra-passe aqui';

  @override
  String get agentAdHocSessions => 'Conexões temporárias';

  @override
  String get agentSaveServerTitle => 'Salvar como servidor';

  @override
  String get agentSaveServerTip =>
      'Este host e a palavra-passe que escrever ficam guardados neste dispositivo';

  @override
  String get agentMonitorOptional => 'Agente monitor (opcional)';

  @override
  String get authFailTip => 'Falha na autenticação. Verifique os dados';

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
  String get connectAll => 'Conectar tudo';

  @override
  String get disconnectAll => 'Desconectar tudo';

  @override
  String get distIcon => 'Marcas de distribuição';

  @override
  String get distIconIntroLegal =>
      'Uma marca indica apenas o que este dispositivo leu do sistema remoto, informação que pode estar errada ou desatualizada, e não identifica um derivado, uma recompilação nem uma versão específica. Quando não é possível identificar, é desenhado um ícone genérico.\n\nCada marca é uma marca registrada de seu respectivo proprietário e é usada aqui apenas para se referir ao sistema que identifica.';

  @override
  String get distIconTip =>
      'Mostrar ao lado de cada servidor uma pequena marca do sistema que ele parece executar';

  @override
  String get distNameMap => 'Correspondência de nomes';

  @override
  String get distNameMapTip =>
      'Apenas para uma distribuição cujo arquivo tenha outro nome onde você hospeda as marcas. A chave é o nome que este aplicativo usa; o valor é o nome a ser buscado. Deixe vazio enquanto nenhuma marca estiver faltando.';

  @override
  String get logoUrl => 'URL do logotipo';

  @override
  String get logoUrlTip =>
      'A imagem grande no topo da página de um servidor, nas cores originais.';

  @override
  String get globe => 'Globo';

  @override
  String get locationTip =>
      'Onde este servidor é desenhado no globo. Latitude e depois longitude, em graus — por exemplo 39.9042, 116.4074.';

  @override
  String get markUrl => 'URL da marca';

  @override
  String get markUrlTip =>
      'A marca pequena ao lado do nome de um servidor nas listas. Vazio: nenhuma.\n\nNão é a mesma imagem do logotipo';

  @override
  String get navTabMenuTip =>
      'Toque e segure uma aba — ou clique com o botão direito — para conectar ou desconectar tudo nela de uma vez.';

  @override
  String nTags(int count) {
    return '$count tags';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Backups remotos exigem uma senha de backup não vazia';

  @override
  String get monitorHttpsRequired =>
      'Um agente monitor remoto precisa de HTTPS, a não ser que HTTP seja permitido.';

  @override
  String get monitorAllowInsecureHttp => 'Permitir HTTP';

  @override
  String get plainHttpTitle =>
      'Este agente é servido por HTTP sem criptografia';

  @override
  String get plainHttpTip =>
      'A senha e tudo o que este app pede trafegariam sem criptografia. Nada foi enviado ainda.';

  @override
  String get allowForThisServer => 'Permitir para este servidor';

  @override
  String get viewError => 'Ver o erro';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Apenas numa rede privada de confiança que cifre o transporte, como a Tailscale';

  @override
  String monitorHttpTip(String url) {
    return 'Ler o estado deste servidor pela API HTTP de um agente **monitor**, em vez de executar comandos por SSH.\n\nÉ preciso instalar o agente no servidor primeiro; as tendências, a app do relógio e os widgets dependem dele.\n\n[Instalar um agente monitor]($url)';
  }

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
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
    return 'Último backup: $lastModified\nEstado: $remoteState';
  }

  @override
  String get bgRun => 'Execução em segundo plano';

  @override
  String get bgRunTip =>
      'Este interruptor indica que o programa tentará rodar em segundo plano, mas a capacidade de fazer isso depende das permissões concedidas. No Android nativo, desative a \'Otimização de bateria\' para este app, no MIUI, altere a estratégia de economia de energia para \'Sem restrições\'.';

  @override
  String get trayReadings => 'Leituras';

  @override
  String get trayChart => 'Gráfico';

  @override
  String get trayChartNone => 'Nenhum';

  @override
  String get trayCompact => 'Linhas compactas';

  @override
  String get trayCompactTip =>
      'Uma linha por servidor, sem o gráfico. O Linux usa sempre um esquema de linha única porque o menu do painel é enviado através do D-Bus, que transporta uma etiqueta em vez de um esquema personalizado; ainda pode incluir o gráfico selecionado como imagem.';

  @override
  String get trayKeepRunning => 'Continuar em execução na bandeja';

  @override
  String get trayKeepRunningTip =>
      'Ao fechar a janela, a app permanece na barra de menus ou na área de notificação e continua a monitorizar os seus servidores. Desative esta opção para que o botão de fechar encerre a app.';

  @override
  String get bgRunNeedsNotification =>
      'Correr em segundo plano precisa de uma notificação permanente, e esta app não tem permissão de notificações. Toca para a conceder.';

  @override
  String get clearAllStatsContent =>
      'Tem certeza de que deseja limpar todas as estatísticas de conexão do servidor? Esta ação não pode ser desfeita.';

  @override
  String get clearAllStatsTitle => 'Limpar todas as estatísticas';

  @override
  String clearServerStatsContent(String serverName) {
    return 'Tem certeza de que deseja limpar as estatísticas de conexão para o servidor \"$serverName\"? Esta ação não pode ser desfeita.';
  }

  @override
  String clearServerStatsTitle(String serverName) {
    return 'Limpar estatísticas de $serverName';
  }

  @override
  String get clearThisServerStats => 'Limpar estatísticas deste servidor';

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
  String get diskHealth => 'Saúde do disco';

  @override
  String get displayCpuIndex => 'Exiba o índice de CPU';

  @override
  String dl2Local(String fileName) {
    return 'Baixar $fileName para o local?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Não há contêineres em execução.\nIsso pode ser porque:\n- O usuário que instalou o Docker difere do usuário configurado no app\n- A variável de ambiente DOCKER_HOST não foi lida corretamente. Você pode verificar isso executando `echo \$DOCKER_HOST` no terminal.';

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
  String fileTooLarge(String file, String size, String sizeMax) {
    return 'Arquivo \'$file\' muito grande \'$size\', excedendo $sizeMax';
  }

  @override
  String get fileDirGone => 'Esta pasta já não está aqui';

  @override
  String get fileDirGoneTip => 'Foi eliminado ou renomeado';

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
  String get ignoreCert => 'Ignorar certificado';

  @override
  String get image => 'Imagem';

  @override
  String get macDmgBody =>
      'A App Store exige que esta app corra em sandbox, e uma sandbox não pode abrir um terminal. A versão DMG pode.\n\nA versão da App Store pode deixar de ser atualizada.';

  @override
  String get macDmgImportDenied =>
      'O macOS não permitiu ler os dados da versão anterior';

  @override
  String get macDmgImported => 'Dados da versão anterior importados';

  @override
  String get macDmgImportFailed =>
      'Não foi possível ler os dados da versão anterior';

  @override
  String get macDmgTip =>
      'Terminal local e executar snippets localmente (versão DMG)';

  @override
  String get macDmgTitle => 'Versão DMG';

  @override
  String get showHiddenFiles => 'Mostrar ficheiros ocultos';

  @override
  String get sshKeyAlgorithm => 'Algoritmo';

  @override
  String get sshKeyComment => 'Comentário';

  @override
  String get sshKeyGenerate => 'Gerar par de chaves';

  @override
  String get sshKeyGenerating => 'A gerar…';

  @override
  String sshKeyLockedFmt(String name) {
    return 'A chave privada [$name] não foi desbloqueada.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'Opcional. Uma chave com frase-passe é guardada cifrada e esta é pedida na primeira vez que uma ligação a usa.';

  @override
  String get sshKeyPassphraseWrong => 'Frase-passe incorreta.';

  @override
  String get sshKeyPublicKey => 'Chave pública';

  @override
  String get sshKeyPublicKeyTip =>
      'Acrescente esta linha a ~/.ssh/authorized_keys no servidor.';

  @override
  String get sshKeyRecommended => 'Recomendado';

  @override
  String sshKeyUnlockTip(String name) {
    return 'Introduza a frase-passe da chave privada [$name].';
  }

  @override
  String get ungrouped => 'Sem grupo';

  @override
  String get containerReclaimable => 'Recuperável';

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
  String get pruneDanglingImagesTip => 'Remove apenas as imagens pendentes.';

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
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return 'Servidores de salto não encontrados para $serverName: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
    return '\"$name\" já existe';
  }

  @override
  String get noJumpServerAvailable => 'Nenhum servidor de salto disponível.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Servidor de salto e ProxyCommand não podem ser usados juntos.';

  @override
  String get noConnectionMethod => 'Configure SSH, um agente monitor, ou ambos';

  @override
  String get preferredTransport => 'Tentar primeiro';

  @override
  String get preferredTransportTip =>
      'De onde o estado é lido e que ligação um comando abre primeiro. A outra continua disponível.';

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
      'Com que shell arranca um terminal. Vazio repõe /bin/sh.';

  @override
  String get linuxNetTip =>
      'Servidores DNS. Vazio repõe os valores por omissão';

  @override
  String madeWithLove(String myGithub) {
    return 'Feito com ❤️ por $myGithub';
  }

  @override
  String get maxConcurrency => 'Concorrência máxima';

  @override
  String get maxRetryCount =>
      'Número de tentativas de reconexão com o servidor';

  @override
  String mismatchSystem(String system) {
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
  String get openLastPath => 'Abrir o último caminho';

  @override
  String get openLastPathTip =>
      'Registros diferentes para servidores diferentes, e registra o caminho ao sair';

  @override
  String get parseContainerStatsTip =>
      'Análise de status do Docker pode ser lenta';

  @override
  String get preferDiskAmount => 'Priorizar a exibição da capacidade do disco';

  @override
  String get privateKey => 'Chave privada';

  @override
  String privateKeyNotFoundFmt(String keyId) {
    return 'Chave privada [$keyId] não encontrada.';
  }

  @override
  String get bmcPowerOnAction => 'Ligar';

  @override
  String get bmcShutdown => 'Desligar';

  @override
  String get bmcForceOff => 'Forçar desligamento';

  @override
  String get restart => 'Reiniciar';

  @override
  String get bmcPowerCycle => 'Ciclo de energia';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'Enviar isto para $server? Será pedido \"$resetType\" ao serviço';
  }

  @override
  String get bmcPowerDone => 'O estado de energia mudou';

  @override
  String get bmcPowerAccepted =>
      'Aceite, mas o estado de energia não mudou. Uma operação suave depende do sistema operativo';

  @override
  String get bmcPowerUnsupported =>
      'Este serviço não permite nada para essa ação';

  @override
  String get bmcUnauthorized => 'O BMC recusou a conta';

  @override
  String get bmcAccountMissing => 'Nenhuma conta definida para este BMC';

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
  String get bmcMultipleSystems => 'Apenas o primeiro sistema é mostrado';

  @override
  String get bmcTip =>
      'O BMC é um computador à parte na placa principal, alcançável quando o sistema operativo do anfitrião não está. Configurado aqui, reporta o estado de energia e os sensores de hardware enquanto o servidor está desligado ou bloqueado. Requer Redfish, presente na maioria do hardware empresarial desde cerca de 2016.';

  @override
  String get bmcCert => 'Certificado';

  @override
  String get bmcCertPinned => 'Verificado e fixado';

  @override
  String get bmcCertUnreviewed =>
      'Ainda não revisto — toque para ver o certificado';

  @override
  String get bmcCertReview =>
      'Um certificado autoassinado. Compare-o antes de aceitar. Depois só esse é confiado.';

  @override
  String get bmcCertChanged => 'O certificado não corresponde. Verifique-o.';

  @override
  String get bmcCertExpired => 'Expirado.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Aceite anteriormente: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'O endereço do BMC tem de ser um URL, p. ex. https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Esta versão corre em sandbox: o comando recebe um home vazio, não o seu, por isso falha tudo o que leia ~/.ssh. A versão DMG não.';

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
  String get liveActivity => 'Atividade ao vivo';

  @override
  String get liveActivityTip =>
      'Mostra sessões do terminal na Tela Bloqueada e na Dynamic Island. O nome do servidor e o estado da conexão ficam visíveis sem desbloquear o dispositivo.';

  @override
  String get liveActivitySystemDisabled =>
      'O iOS não está permitindo. Os controles estão em Ajustes › ServerBox › Atividades ao Vivo e Ajustes › Face ID e Código › Atividades ao Vivo.';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand só é suportado em plataformas desktop.';

  @override
  String get pveIgnoreCertTip =>
      'Não recomendado para ativar, cuidado com os riscos de segurança! Se estiver usando o certificado padrão do PVE, você precisa habilitar esta opção.';

  @override
  String get pvePasswordRequired =>
      'A senha do PVE é obrigatória. Defina-a nas configurações do servidor.';

  @override
  String get pveOtpRequired =>
      'A autenticação em duas etapas está ativa neste servidor PVE. Informe o código OTP.';

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
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return '$distro $installed está instalado; há $latest. Atualizar substitui todo o contentor: os dados do $pm perdem-se';
  }

  @override
  String linuxSystemInUse(String name) {
    return 'Feche os terminais em $name antes de o eliminar';
  }

  @override
  String get rootfsSubtitle => 'Um espaço de usuário Linux neste dispositivo';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
    return 'Descarrega $distro $version (cerca de $size MB) e extrai neste dispositivo.';
  }

  @override
  String get sameIdServerExist => 'Já existe um servidor com o mesmo ID';

  @override
  String get second => 'Segundo';

  @override
  String get serverFilesUnavailableTip =>
      'Precisa de SSH para este servidor, ou do server_box_monitor com a API de ficheiros ligada.';

  @override
  String get back => 'Voltar';

  @override
  String get history => 'Histórico';

  @override
  String get homeDir => 'Pasta pessoal';

  @override
  String selected(int count) {
    return '$count selecionados';
  }

  @override
  String get sendTo => 'Enviar para…';

  @override
  String get serverFuncBtns => 'Botões de função do servidor';

  @override
  String get serverOrder => 'Ordem do servidor';

  @override
  String get serverTabEmpty => 'Ainda não há servidores';

  @override
  String get serverTabRequired => 'A aba do servidor não pode ser removida';

  @override
  String get shareCodeHint =>
      'Informe estes dígitos separadamente ao destinatário. Eles não estão incluídos no código QR.';

  @override
  String get shareCodePrompt => 'Código de 6 dígitos';

  @override
  String get shareCodeTitle => 'Código de uso único';

  @override
  String get shareExpired => 'Este compartilhamento expirou. Solicite um novo.';

  @override
  String get shareImportFile => 'De um arquivo compartilhado';

  @override
  String get shareImportTitle => 'Importar servidor compartilhado';

  @override
  String get shareIncludesKey => 'O compartilhamento inclui a chave privada.';

  @override
  String get shareOmittedBmc =>
      'As credenciais do BMC. O endereço está incluído, mas as credenciais não.';

  @override
  String get shareOmittedJump =>
      'O servidor de salto, pois ele está salvo como outro servidor neste dispositivo.';

  @override
  String get shareOmittedKeyPath =>
      'O arquivo de chave, pois o caminho só é válido neste dispositivo.';

  @override
  String get shareOmittedMissingKey =>
      'A chave privada, pois ela não está no armazenamento de chaves deste dispositivo.';

  @override
  String get shareOmittedTip =>
      'Não incluído; o destinatário precisa configurar:';

  @override
  String get sharePassphraseTip =>
      'Esta senha criptografa o arquivo. O destinatário precisa dela para importar o servidor, e ela não pode ser recuperada.';

  @override
  String shareQrTip(int minutes) {
    return 'Os dados de conexão deste código QR estão criptografados. O compartilhamento expira em $minutes minutos.';
  }

  @override
  String get shareScanQr => 'Ler um código QR';

  @override
  String shareServerExists(String name) {
    return '“$name” já usa este endereço neste dispositivo. Importar mesmo assim?';
  }

  @override
  String get shareTooBigForQr =>
      'Grande demais para um código QR. Compartilhe como arquivo.';

  @override
  String get shareTooNew =>
      'Este compartilhamento foi criado com uma versão mais recente do ServerBox. Atualize o aplicativo para abri-lo.';

  @override
  String get shareUnreadable =>
      'Este não é um compartilhamento válido do ServerBox.';

  @override
  String get shareVia => 'Compartilhar via';

  @override
  String get sftpDlPrepare => 'Preparando para conectar ao servidor...';

  @override
  String get sftpEditorTip =>
      'Vazio usa o editor integrado. Por exemplo `vim` (sugere-se ler `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Usar `rm -r` em SFTP para excluir pastas';

  @override
  String get sftpSSHConnected => 'SFTP conectado...';

  @override
  String get sftpShowFoldersFirst => 'Mostrar pastas primeiro';

  @override
  String get sftpUnavailableUseScp =>
      'Se este host não tiver subsistema SFTP, como acontece em muitos dispositivos embarcados, mude a transferência de ficheiros para SCP nas definições do servidor.';

  @override
  String get sshFileTransportTip =>
      'SFTP serve para qualquer equipamento atual. Escolhe SCP para um host antigo ou embarcado cujo servidor SSH não tem subsistema SFTP: precisa do comando `scp` e de uma shell que tenha também os utilitários de ficheiros habituais (`find`, `stat`, `mv`, `chmod`).';

  @override
  String get specifyDev => 'Especificar dispositivo';

  @override
  String get specifyDevTip =>
      'O tráfego de rede conta todos os dispositivos; indique um aqui';

  @override
  String get tempIsCelsiusTip =>
      'Quando ativado, o valor de temperatura é tratado como Celsius em vez de milicelsius. Ative apenas se a temperatura aparecer errada (por exemplo, 0,1 °C em vez de 58 °C).';

  @override
  String spentTime(String time) {
    return 'Tempo gasto: $time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
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
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return '$duplicateCount duplicatas serão ignoradas';
  }

  @override
  String get sshConfigFound => 'Encontramos configuração SSH no seu sistema';

  @override
  String sshConfigFoundServers(int totalCount) {
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
  String sshConfigImported(int count) {
    return 'Importados $count servidores da configuração SSH';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
    return 'A chave de host SSH de $serverName foi alterada. Continue apenas se confiar neste servidor.';
  }

  @override
  String get sshHostKeyType => 'Tipo de chave de host SSH';

  @override
  String get sshKnownHostKeys => 'Anfitriões conhecidos';

  @override
  String get sshKnownHostKeysTip => 'As chaves de host que esta app aceitou';

  @override
  String sshHostKeyNewDesc(String serverName) {
    return 'Uma nova chave de host SSH foi recebida de $serverName. Verifique a impressão digital antes de confiar.';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
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
  String sshConfigServersToImport(int importCount) {
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
  String switchTo(String val) {
    return 'Mudar para $val';
  }

  @override
  String get syncAppSettings => 'Sincronizar as configurações do app';

  @override
  String get syncAppSettingsTip =>
      'Incluir tema, layout, editor, terminal e outras preferências do dispositivo na sincronização automática.';

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
  String get virtKeyRows => 'Linhas exibidas de uma vez';

  @override
  String get virtKeyRowsTip =>
      'O restante fica em uma página própria, deslizada para o lado.';

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
  String portForward_deleteConfirmFmt(String name) {
    return 'Excluir $name?';
  }

  @override
  String get sponsor => 'Patrocinador';

  @override
  String get sortByJoinTime => 'Por data de adição';

  @override
  String get portForwardBetaTitle => 'Encaminhamento de portas (Beta)';

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
  String get processSearchHint => 'Nome, usuário ou PID';

  @override
  String processShowKernelThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar $count threads do kernel',
      one: 'Mostrar 1 thread do kernel',
    );
    return '$_temp0';
  }

  @override
  String get processForceKill => 'Encerrar à força';

  @override
  String get processStarted => 'Iniciado';

  @override
  String get processThreads => 'Threads';

  @override
  String get watchServers => 'Servidores no relógio';

  @override
  String get watchServersTip =>
      'O relógio consulta o monitor sozinho, por isso só se podem escolher servidores com um.';

  @override
  String get watchNoMonitorServer =>
      'Nenhum servidor tem um agente monitor configurado';

  @override
  String get legacyStatusGoneTitle => 'As URLs de estado deixaram de funcionar';

  @override
  String get legacyStatusGoneBody =>
      'A app do relógio e os widgets liam um endereço `/status` escrito à mão. Esse endpoint foi removido: só conseguia devolver valores atuais como texto, e por isso nunca puderam mostrar um gráfico.\n\nAgora leem a API autenticada do agente monitor, desenham tendências e mantêm-se sincronizados com a app sozinhos. Configure o servidor uma vez na app e cada relógio e widget passa a usá-lo.';

  @override
  String get services => 'Serviços';

  @override
  String get status => 'Estado';

  @override
  String get enable => 'Ativar';

  @override
  String get disable => 'Desativar';

  @override
  String get starting => 'A iniciar';

  @override
  String get stopping => 'A parar';

  @override
  String get serviceManagerUnsupported => 'Gestor de serviços não suportado';

  @override
  String get serviceManagerUnsupportedTip =>
      'Este servidor usa um gestor que o ServerBox ainda não suporta. systemd, procd e OpenRC são suportados.';

  @override
  String serviceManagerFmt(String manager) {
    return 'Gerido por $manager';
  }

  @override
  String get serviceListFailed => 'Não foi possível listar os serviços';

  @override
  String get serviceDetailsUnavailable =>
      'Alguns detalhes dos serviços não estão disponíveis';

  @override
  String get serviceDetailsUnavailableTip =>
      'A lista pode ser usada, mas o gestor não devolveu todas as informações de estado ou arranque.';

  @override
  String get systemdUserScopeMissing => 'As units de usuário não são listadas';

  @override
  String get systemdUserScopeMissingTip =>
      'Esta conta não tem barramento de sessão de usuário no servidor, então apenas as units do sistema são exibidas.';

  @override
  String get serviceSearchHint => 'Nome da unidade';

  @override
  String get serviceNeedsAttention => 'Requer atenção';

  @override
  String serviceOtherUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count outras unidades',
      one: '1 outra unidade',
    );
    return '$_temp0';
  }

  @override
  String get serviceUnit => 'Unit';

  @override
  String get serviceUnitType => 'Tipo';

  @override
  String get serviceScope => 'Escopo';

  @override
  String get serviceStartup => 'Inicialização';

  @override
  String serviceUpFor(String duration) {
    return 'ativo há $duration';
  }

  @override
  String serviceDownFor(String duration) {
    return 'inativo há $duration';
  }

  @override
  String serviceNextIn(String duration) {
    return 'próximo em $duration';
  }

  @override
  String serviceStoppedAgo(String duration) {
    return 'Parado há $duration';
  }

  @override
  String serviceExitStatus(int code) {
    return 'status de saída $code';
  }

  @override
  String get serviceFullJournal => 'Journal completo';

  @override
  String get serviceUnitFile => 'Arquivo da unidade';

  @override
  String serviceJournalRecent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Últimas $count linhas',
      one: 'Última linha',
    );
    return '$_temp0';
  }

  @override
  String get serviceJournalUnreadable => 'Esta conta não pode ler o journal';

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
  String get fan => 'Ventoinha';

  @override
  String get clockSpeed => 'Clock';

  @override
  String get vendor => 'Fabricante';

  @override
  String get continueInTerminal => 'Continuar no terminal';

  @override
  String get askAiRiskUnknown => 'Não classificado';

  @override
  String get agentLocalExec => 'Executar comandos neste dispositivo';

  @override
  String get agentLocalExecTip =>
      'Deixa o Agent trabalhar na máquina que executa o ServerBox. Mesmo os comandos só de leitura são revistos';

  @override
  String get agentLocalExecRootfsTip =>
      'Deixa o Agent trabalhar localmente, limitado ao contentor Linux que o ServerBox instalou';

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

  @override
  String get bmcStaleWrite =>
      'O BMC mudou durante a gravação. Tente novamente.';

  @override
  String get send => 'Enviar';

  @override
  String get privacyBlur => 'Privacidade em segundo plano';

  @override
  String get privacyBlurTip => 'Ocultar o conteúdo do app no alternador';

  @override
  String get floatReturnToTab => 'Voltar para a aba';

  @override
  String get termInFloatWindow => 'Este terminal está na janela flutuante';

  @override
  String get globeEnabledTip =>
      'Desenhar os servidores num globo, onde estão os seus endereços. Desligado remove o botão e para todas as pesquisas.';

  @override
  String get geoShardsConsentAttribution =>
      'Geolocalização de IP por [DB-IP](https://db-ip.com), CC BY 4.0.';

  @override
  String get geoMissPrivate => 'Endereço privado';

  @override
  String get geoMissNoData => 'Sem dados de localização';

  @override
  String get globeGuide =>
      'Toque aqui para ver os servidores num globo, onde ficam os seus endereços.';

  @override
  String get publicIp => 'IP público';

  @override
  String get geoData => 'Dados ao nível da cidade';

  @override
  String get geoDataTip =>
      'Após o download, todas as consultas de localização usam os dados armazenados neste dispositivo. Nenhum endereço de servidor ou atividade de consulta é enviado ao serviço de download.';

  @override
  String get geoDataMissing => 'Não transferidos';

  @override
  String get geoDataUnreachable => 'Não foi possível obter os dados.';

  @override
  String get geoDataRemoveFailed => 'Não foi possível excluir os dados.';

  @override
  String geoDataCurrent(String month) {
    return '$month já está instalado.';
  }

  @override
  String geoDataConsent(String download, String disk) {
    return '**Download: $download · Armazenamento no dispositivo: $disk.** O conjunto de dados completo fica armazenado neste dispositivo e todas as consultas de localização posteriores são feitas localmente. Nenhum endereço de servidor ou atividade de consulta é enviado ao serviço de download.\n\nAtualizado mensalmente. Uma versão mais recente substitui os dados instalados sem manter uma cópia adicional. Você pode excluí-los a qualquer momento.';
  }

  @override
  String get benchmark => 'Teste de desempenho';

  @override
  String get benchmarkIntro =>
      'Executa o Yet Another Bench Script neste servidor para testar disco, rede e CPU. Uma execução completa leva de 10 a 20 minutos e continua mesmo se você sair desta página ou fechar o aplicativo.';

  @override
  String get benchmarkNoRuns => 'Ainda não há testes de desempenho.';

  @override
  String get benchmarkRunning => 'Teste de desempenho em andamento';

  @override
  String get benchmarkStartFailed =>
      'Não foi possível iniciar o teste de desempenho';

  @override
  String get benchmarkCancelConfirm =>
      'Interromper este teste? Todas as medições feitas até agora serão perdidas.';

  @override
  String get benchmarkDeleteConfirm => 'Excluir o resultado deste teste?';

  @override
  String get benchmarkNothingSelected =>
      'Todas as etapas estão desativadas. Apenas as informações do sistema serão coletadas, o que leva alguns segundos.';

  @override
  String get benchmarkDiskTip =>
      'fio com quatro tamanhos de bloco; cerca de 3 minutos. Grava um arquivo de teste de 2 GB no diretório de trabalho e requer esse espaço livre.';

  @override
  String get benchmarkNetworkTip =>
      'iperf3 com servidores públicos; cerca de 4 minutos.';

  @override
  String get benchmarkReducedNetwork => 'Menos locais';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return 'Três locais em vez de sete. O tráfego estimado cai de $full para $reduced.';
  }

  @override
  String get benchmarkCpuTip =>
      'Baixa o Geekbench, um programa proprietário, e **publica o resultado em uma página pública no geekbench.com**, incluindo modelo da CPU, número de núcleos e memória.';

  @override
  String get benchmarkSensitiveOptions =>
      'As opções abaixo baixam e executam software de terceiros neste servidor ou enviam informações do servidor a terceiros. Elas ficam desativadas por padrão.';

  @override
  String get benchmarkIpInfoTip =>
      'Envia o endereço público deste servidor ao ip-api.com por HTTP sem criptografia.';

  @override
  String get benchmarkIpInfo => 'Consultar proprietário do IP';

  @override
  String get benchmarkPreferBin => 'Baixar fio e iperf3';

  @override
  String get benchmarkPreferBinTip =>
      'Baixa os programas do GitHub em vez de usar os pacotes do host. Ative somente se nenhum dos dois estiver instalado no host.';

  @override
  String get benchmarkWorkDir => 'Diretório de trabalho';

  @override
  String get benchmarkWorkDirTip =>
      'Determina qual sistema de arquivos será medido pelo teste de disco. Se ficar vazio, usa o diretório inicial da conta de login.';

  @override
  String benchmarkEstimatedTime(int minutes) {
    return 'Cerca de $minutes min';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return 'Cerca de $size de tráfego';
  }

  @override
  String get benchmarkPhaseSystem => 'Lendo informações do sistema';

  @override
  String get benchmarkPhaseDisk => 'Testando o disco';

  @override
  String get benchmarkPhaseNetwork => 'Testando a rede';

  @override
  String get benchmarkPhaseCpu => 'Testando a CPU';

  @override
  String get benchmarkPhaseDone => 'Finalizando';

  @override
  String get benchmarkResultUnreadable =>
      'Não foi possível ler este resultado como JSON. O texto original está abaixo.';

  @override
  String get benchmarkViewOnGeekbench => 'Ver no Geekbench';

  @override
  String get benchmarkGeekbenchPublic =>
      'Este resultado está publicado no link acima e pode ser acessado por qualquer pessoa.';

  @override
  String get benchmarkSingleCore => 'Núcleo único';

  @override
  String get benchmarkMultiCore => 'Vários núcleos';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => 'Upload';

  @override
  String get benchmarkRecv => 'Download';

  @override
  String get benchmarkLatency => 'Latência';

  @override
  String get benchmarkVirt => 'Virtualização';

  @override
  String get benchmarkRawLog => 'Log de execução';

  @override
  String benchmarkUpstream(String version) {
    return 'Desenvolvido com Yet Another Bench Script ($version)';
  }

  @override
  String get benchmarkPhaseStarting => 'Iniciando';

  @override
  String get benchmarkNoOutputYet =>
      'Ainda não há saída. Antes de exibir a primeira linha, o YABS verifica se google.com e icanhazip.com estão acessíveis. Em redes que bloqueiam qualquer um desses sites, isso pode levar vários minutos.';

  @override
  String get tagsEmptyTip =>
      'Ainda não há tags. Adicione uma ao editar um servidor, e ela aparecerá aqui.';

  @override
  String get benchmarkNoServers =>
      'Adicione um servidor primeiro e volte depois para executar o benchmark.';

  @override
  String get schemaTooNewTitle => 'Estes dados são mais recentes que o app';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return 'Eles foram gravados por uma versão mais recente do ServerBox (armazenamento v$stored); esta versão lê até v$supported. Nada foi alterado.';
  }

  @override
  String get schemaTooNewReinstall =>
      'Reinstale a versão mais recente para abrir tudo como antes.';

  @override
  String get schemaTooNewExportPlain => 'Exportar sem senha';

  @override
  String get schemaTooNewPlainWarn =>
      'O arquivo conterá, em texto simples, todas as chaves privadas SSH, senhas de servidores e chaves de API. Quem obtiver o arquivo terá acesso a tudo isso.';

  @override
  String get schemaTooNewWipe => 'Excluir todos os dados';

  @override
  String get schemaTooNewWipeConfirm =>
      'Todos os servidores, chaves, snippets e configurações deste dispositivo serão excluídos, sem possibilidade de desfazer. Um backup exportado aqui seria a única cópia restante.';

  @override
  String get schemaTooNewWipeDone =>
      'Dados excluídos. Abra o app novamente para começar do zero.';

  @override
  String get schemaTooNewWipeFailed =>
      'Não foi possível excluir alguns dados, e esta versão ainda não consegue abrir o que restou. Reinstale a versão mais recente para acessá-los.';

  @override
  String get systemUsers => 'Usuários';

  @override
  String get userManagerLinuxOnly =>
      'No momento, o gerenciamento de usuários do sistema é compatível apenas com servidores Linux.';

  @override
  String get userRegularAccount => 'Comum';

  @override
  String get userCurrentAccount => 'Conta atual';

  @override
  String get userSystemAccount => 'Conta do sistema';

  @override
  String get userUid => 'UID';

  @override
  String get userLoginStatus => 'Status';

  @override
  String get userLoginEnabled => 'Login ativado';

  @override
  String get userDetailAccount => 'Account';

  @override
  String get userDetailSecurity => 'Segurança';

  @override
  String get userSshKeys => 'SSH keys';

  @override
  String get userExpires => 'Expira';

  @override
  String get userNever => 'Nunca';

  @override
  String get userPasswordSet => 'Definida';

  @override
  String get userPasswordLocked => 'Bloqueada';

  @override
  String get userPasswordNone => 'Nenhuma';

  @override
  String get userSuperuser => 'Superuser';

  @override
  String get userOpenShell => 'Abrir shell';

  @override
  String get userRootChangesWarning =>
      'As alterações no root entram em vigor imediatamente em todas as sessões.';

  @override
  String get userComment => 'Comentário';

  @override
  String get userPrimaryGroup => 'Grupo principal';

  @override
  String get userSupplementaryGroups => 'Grupos suplementares';

  @override
  String get userLoginShell => 'Shell de login';

  @override
  String get userCreateHome => 'Criar diretório home';

  @override
  String get userMoveHome =>
      'Mover o diretório home existente quando o caminho mudar';

  @override
  String get userRemoveHome => 'Remover o diretório home';

  @override
  String get userPasswordCreateTip =>
      'Deixe a senha vazia para criar uma conta com login por senha bloqueado.';

  @override
  String get userPasswordEditTip =>
      'Deixe a senha vazia para manter a senha atual.';

  @override
  String funcUnavailableFmt(String func) {
    return '$func não está disponível pela conexão deste servidor.';
  }

  @override
  String get rangeLive => 'Ao vivo';

  @override
  String get diskIo => 'E/S de disco';

  @override
  String get peak => 'pico';

  @override
  String get hardware => 'Hardware';

  @override
  String get cores => 'Núcleos';

  @override
  String get historyNoStored =>
      'Apenas um agente monitor armazena histórico. Esta conexão guarda o que o app viu desde que se conectou.';

  @override
  String get noHistoryYet => 'Nada medido ainda';

  @override
  String get noData => 'sem dados';

  @override
  String get from => 'De';

  @override
  String get to => 'Até';

  @override
  String get beyondRetention => 'além do que este agente guardou';

  @override
  String agentRetentionFmt(String kept) {
    return 'O agente guarda $kept';
  }

  @override
  String oldestSampleFmt(String time) {
    return 'amostra mais antiga $time';
  }

  @override
  String get rangeEndsBeforeItStarts =>
      'O fim do intervalo precisa ser depois do início.';

  @override
  String get samples => 'amostras';

  @override
  String get unavailable => 'indisponível';

  @override
  String get metricUnavailableTip =>
      'O resto da página não é afetado. Verifique no host o comando de onde vem esta leitura.';

  @override
  String get waitingFirstSample => 'Aguardando a primeira amostra';

  @override
  String atTimeFmt(String time) {
    return 'às $time';
  }

  @override
  String get stored => 'armazenado';

  @override
  String lastSampleFmt(String ago) {
    return 'última amostra $ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return 'Tudo abaixo é de $time, $ago.';
  }

  @override
  String noDataBeforeFmt(String time) {
    return 'sem dados antes de $time';
  }

  @override
  String loadingRangeFmt(String range) {
    return 'Carregando $range…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return 'Sem histórico armazenado de $metric';
  }

  @override
  String devicesFmt(int count) {
    return '$count dispositivos';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return '$count dispositivos · $name o mais ocupado';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$plotted de $total dispositivos';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return '$count sensores · $name o mais quente';
  }

  @override
  String get oneDeviceAtLeast =>
      'Pelo menos um dispositivo permanece no gráfico.';

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$shown de $total $what';
  }

  @override
  String countOfFmt(int count, String what) {
    return '$count $what';
  }

  @override
  String get unitDevices => 'dispositivos';

  @override
  String get unitSensors => 'sensores';

  @override
  String get unitBatteries => 'baterias';

  @override
  String get unitCommands => 'comandos';

  @override
  String get unitReadings => 'leituras';

  @override
  String get unitGpus => 'GPUs';

  @override
  String get hottest => 'o mais quente';

  @override
  String get oldest => 'o mais antigo';

  @override
  String get notApplicable => 'não aplicável';

  @override
  String get attributes => 'atributos';

  @override
  String get powerOnHours => 'Horas ligado';

  @override
  String get powerCycles => 'Ciclos de energia';

  @override
  String get lifeLeft => 'Vida restante';

  @override
  String get lifetimeWrite => 'Escrita total';

  @override
  String get lifetimeRead => 'Leitura total';

  @override
  String get averageErase => 'Apagamentos médios';

  @override
  String get unsafeShutdowns => 'Desligamentos inseguros';

  @override
  String get diskAllPassed => 'todos PASSED';

  @override
  String diskWarningFmt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avisos',
      one: '1 aviso',
    );
    return '$_temp0';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$wrong de $total dispositivos';
  }

  @override
  String get diskSmartSortedTip => 'Piores primeiro';

  @override
  String readAgoFmt(String ago) {
    return 'lido $ago';
  }

  @override
  String processesFmt(int count) {
    return '$count processos';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count com falha';
  }

  @override
  String get diskSmartOpenTip => 'Toque para ver os atributos';

  @override
  String get cycle => 'Ciclos';

  @override
  String get window => 'janela';

  @override
  String ofFmt(String total) {
    return 'de $total';
  }

  @override
  String get serverDetailCards => 'Cartões da página de detalhes';

  @override
  String get connection => 'Conexão';

  @override
  String get connectionTip =>
      'Os dois podem estar ligados ao mesmo tempo. A ordem é a ordem em que são chamados.';

  @override
  String transportOrderFmt(String first, String second) {
    return 'Arraste para mudar a ordem. $first é chamado primeiro; se não responder, $second sustenta a sessão sozinho.';
  }

  @override
  String transportOnlyFmt(String name) {
    return 'Apenas $name está ligado, então não há para onde recorrer.';
  }

  @override
  String get transportNoneOn =>
      'Ambos estão desligados — não é possível conectar a este servidor.';

  @override
  String get transportOffKept =>
      'desligado — configurações mantidas, nunca chamado';

  @override
  String get transportDialledFirst => 'chamado primeiro';

  @override
  String get transportFallback => 'alternativa';

  @override
  String get transportOnlyMethod => 'único método';

  @override
  String get transportOff => 'desligado';

  @override
  String get thisDevice => 'Este dispositivo';

  @override
  String get localServerTip =>
      'Lê este dispositivo diretamente, executando aqui o script de status. SSH e Monitor HTTP não são usados, e as suas configurações são mantidas.';

  @override
  String get localServerUnsupported =>
      'Esta plataforma não consegue ler este dispositivo como servidor. Linux, Windows e a versão DMG do macOS conseguem.';

  @override
  String get remoteDesktopIntro =>
      'Abre o ambiente de trabalho RDP ou VNC de um servidor dentro da app. A conexão passa pela conexão SSH do servidor ou pelo seu agente Monitor, por isso a porta do ambiente de trabalho não precisa de estar acessível a partir da rede.';

  @override
  String get remoteDesktopIntroProfiles =>
      'Guarde um perfil por ambiente de trabalho a partir do botão Área de trabalho remota de um servidor ou do separador Área de trabalho remota.';

  @override
  String get localServerIntro =>
      'Adiciona como servidor o dispositivo que executa o ServerBox. Estado, processos, serviços, contentores, terminal e ficheiros funcionam sem SSH nem agente Monitor.';

  @override
  String get localServerAdd => 'Adicionar este dispositivo';

  @override
  String get localServerIntroFooter =>
      'Também pode ser ativado mais tarde, na página de edição de um servidor, em Conexão.';

  @override
  String get transportSectionOff =>
      'Desligado. Os campos abaixo ficam guardados para quando você ligar de novo.';

  @override
  String get monitorAgent => 'Agente monitor';

  @override
  String get plainHttpEditTip =>
      'Credenciais e métricas atravessam a rede sem criptografia. Mantenha isso em uma LAN ou em um endereço Tailscale, ou coloque o agente atrás de TLS.';

  @override
  String get behaviour => 'Comportamento';

  @override
  String get optional => 'Opcional';

  @override
  String get optionalTip =>
      'Nada aqui é necessário para conectar. Abra um e os campos dele assumem o formulário.';

  @override
  String get sshAdvanced => 'SSH avançado';

  @override
  String get sshAdvancedTip =>
      'Destino alternativo, ProxyCommand, servidor de salto, transporte de arquivos, caminho remoto';

  @override
  String get sshLegacyAlgorithms => 'Algoritmos obsoletos';

  @override
  String get sshLegacyAlgorithmsTip =>
      'Para servidores SSH antigos, como routers ou switches, que oferecem apenas uma chave de host SHA-1 `ssh-rsa` ou uma troca de chaves SHA-1. Menos seguro; ative apenas para hosts que necessitem desta opção.';

  @override
  String get appearanceAndPlace => 'Aparência e local';

  @override
  String get appearanceAndPlaceTip => 'Logotipo, coordenadas';

  @override
  String get statusCollection => 'Coleta de status';

  @override
  String get statusCollectionTip =>
      'Quais comandos rodam, comandos próprios, qual dispositivo ler';

  @override
  String get tagAllTags => 'Todas as tags';

  @override
  String get tagMatching => 'Correspondências';

  @override
  String get tagNewHint => 'Nova tag';

  @override
  String tagCreateFmt(String tag) {
    return 'Criar #$tag';
  }

  @override
  String get tagOnThisServer => 'neste servidor';

  @override
  String tagServersFmt(int count) {
    return '$count servidores';
  }

  @override
  String tagOnThisServerFmt(int count) {
    return '$count neste servidor';
  }

  @override
  String get tagMatchesTyped => 'corresponde ao que você digitou';

  @override
  String get tagEditorTip =>
      'Digitar filtra a lista; o botão cria a tag e a coloca neste servidor em um único passo. O lápis a renomeia em todos os servidores que a carregam. Uma tag que nenhum servidor carrega desaparece ao salvar.';

  @override
  String get tagRenamesOnSave => 'As renomeações são aplicadas ao salvar';

  @override
  String get scheduledTasks => 'Scheduled tasks';

  @override
  String get scheduledTaskLinuxOnly =>
      'No momento, o gerenciamento de tarefas agendadas é compatível apenas com servidores Linux.';

  @override
  String get scheduledTaskUnavailable =>
      'O crontab não está disponível neste servidor.';

  @override
  String get scheduledTaskPreserveTip =>
      'Os comentários, as variáveis de ambiente e as linhas não reconhecidas deste crontab serão preservados.';

  @override
  String get scheduledTaskSchedule => 'Schedule';

  @override
  String get scheduledTaskAdd => 'Add task';

  @override
  String get scheduledTaskNextRun => 'Next run';

  @override
  String scheduledTaskNextInFmt(String time) {
    return 'in $time';
  }

  @override
  String get scheduledTaskEnabled => 'Enabled';

  @override
  String get scheduledTaskCommentedOut => 'Commented out';

  @override
  String scheduledTaskSummaryFmt(int enabled, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total tarefas',
      one: '1 tarefa',
      zero: '$total tarefas',
    );
    String _temp1 = intl.Intl.pluralLogic(
      enabled,
      locale: localeName,
      other: '$enabled ativadas',
      one: '1 ativada',
      zero: '$enabled ativadas',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get scheduledTaskFilterHint => 'Filter tasks';

  @override
  String get scheduledTaskPreserved => 'Preserved lines';

  @override
  String get scheduledTaskRaw => 'Raw crontab';

  @override
  String get scheduledTaskEnableNow => 'Enable now';

  @override
  String get scheduledTaskEnableNowTip =>
      'Quando desativada, a linha é gravada como comentário.';

  @override
  String scheduledTaskEmptyFmt(String user) {
    return 'Não há tarefas agendadas para $user. O que for adicionado aqui será gravado no crontab dessa conta.';
  }

  @override
  String get scheduledTaskFieldMinute => 'Minute';

  @override
  String get scheduledTaskFieldHour => 'Hour';

  @override
  String get scheduledTaskFieldDayOfMonth => 'Dia do mês';

  @override
  String get scheduledTaskFieldMonth => 'Month';

  @override
  String get scheduledTaskFieldDayOfWeek => 'Dia da semana';

  @override
  String get cronErrScheduleEmpty => 'É necessário informar um agendamento.';

  @override
  String get cronErrCommandEmpty => 'É necessário informar um comando.';

  @override
  String get cronErrLineBreak =>
      'Uma linha do crontab não pode conter quebras de linha.';

  @override
  String get cronErrMacro => 'Uma macro é uma única palavra, como @reboot.';

  @override
  String get cronErrFieldCount =>
      'Um agendamento cron tem cinco campos ou uma macro, como @reboot.';

  @override
  String get cronAtBoot => 'At boot';

  @override
  String get cronEveryMin => 'Every minute';

  @override
  String cronEveryMinsFmt(int minutes) {
    return 'A cada $minutes minutos';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return 'A cada hora, no minuto :$minute';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return 'A cada $hours horas';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return 'A cada $hours horas, no minuto :$minute';
  }

  @override
  String cronDailyAtFmt(String time) {
    return 'Todos os dias às $time';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return 'Nos dias úteis às $time';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return 'Toda $day às $time';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
    return 'Todo dia $day de cada mês às $time';
  }

  @override
  String get monitorSettings => 'Monitor settings';

  @override
  String get monitorAgentDefault => 'Agent default';

  @override
  String get monitorNeedsRestart => 'Entra em vigor após reiniciar o agent';

  @override
  String get monitorCollection => 'Collection';

  @override
  String get extendedInterval => 'Intervalo do ciclo estendido';

  @override
  String get idlePause => 'Pausar quando não houver clientes consultando';

  @override
  String get idlePauseTip =>
      'O ciclo estendido executa smartctl, sensors e amd-smi. Pausá-lo quando nenhum cliente estiver consultando evita que um disco seja ativado para coletar dados que ninguém está lendo.';

  @override
  String get idlePauseThreshold => 'Idle after';

  @override
  String get monitorAlerts => 'Alerts';

  @override
  String get monitoringRules => 'Alert rules';

  @override
  String get ruleMonitorType => 'Metric';

  @override
  String get ruleThreshold => 'Threshold';

  @override
  String get ruleMatcher => 'Matcher';

  @override
  String get ruleTip =>
      'Métrica: cpu / memory / swap / disk / network / temperature. Correspondência: cpu0 para um núcleo, used / free / avail para memória, rx / tx para rede; disco e temperatura ignoram este campo. Limite: um operador de comparação e um valor, como >=80%, >=70c ou >10m/s.';

  @override
  String get pushChannels => 'Canais de notificação';

  @override
  String get pushType => 'Type';

  @override
  String get pushRate => 'Rate limit';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => 'Definido no agent, não exibido';

  @override
  String get pushSecretKeep => 'Deixe em branco para manter';

  @override
  String get pushTestTip =>
      'Envia uma notificação por este canal com as configurações atuais, salvas ou não.';

  @override
  String get pushTestSent => 'O canal aceitou a notificação';

  @override
  String get pushTestFailed => 'O canal recusou a notificação';

  @override
  String get pushTestMessage => 'Notificação de teste do ServerBox Monitor';

  @override
  String get pushUnknownType =>
      'Este agent não tem um remetente para este tipo de canal, portanto suas configurações não são exibidas. Ele pode ser removido aqui ou editado no config.toml do agent.';

  @override
  String get pushJsonInvalid => 'não é um JSON válido';

  @override
  String get dataRetention => 'Data retention';

  @override
  String get dataRetentionTip =>
      'Quando desativada, o agent nunca exclui dados e o banco de dados cresce sem limite.';

  @override
  String get retentionMetrics => 'Keep metrics';

  @override
  String get retentionAlerts => 'Keep alerts';

  @override
  String get retentionCleanup => 'Executar limpeza a cada';

  @override
  String get retentionMaxDbSize => 'Limite de tamanho do banco de dados';

  @override
  String get corsOrigins => 'Origens permitidas pelo CORS';

  @override
  String get corsOriginsTip =>
      'Origens a partir das quais um painel web pode acessar este agent. Se ficar vazio, apenas a mesma origem será permitida.';

  @override
  String get monitorNoRemoteAccess =>
      'Este agente está configurado apenas para monitorização. Não pode abrir um terminal, executar comandos ou navegar pelos ficheiros a partir daqui. Para ativar estas funções, edite [remote_access] no config.toml do agente.';

  @override
  String get alerts => 'Alertas';

  @override
  String get online => 'online';

  @override
  String get densityCards => 'Cartões';

  @override
  String get densityRows => 'Linhas';

  @override
  String get densityGrid => 'Grelha';

  @override
  String get connect => 'Ligar';

  @override
  String get disconnect => 'Desligar';

  @override
  String get searchServerTip =>
      'Pesquisa nomes e endereços — os dois dados que o editor pede primeiro.';

  @override
  String get addServerTip =>
      'Preencha um, leia um código QR ou importe um ficheiro partilhado por alguém.';

  @override
  String get move => 'Mover';

  @override
  String get moveToTop => 'Mover para o início';

  @override
  String get moveToBottom => 'Mover para o fim';

  @override
  String get groupByTag => 'Agrupar por tag';

  @override
  String get groupByTagTip => 'As tags são definidas no editor do servidor.';

  @override
  String get connecting => 'A ligar…';

  @override
  String get authShort => 'Auth';

  @override
  String get remoteDesktopFitToWindow => 'Ajustar à janela';

  @override
  String get remoteDesktopActualSize => 'Tamanho real';

  @override
  String get remoteDesktopZoom => 'Ampliação';

  @override
  String get remoteDesktopViewOnly => 'Somente visualização';

  @override
  String get remoteDesktopDisableViewOnly => 'Desativar somente visualização';

  @override
  String get remoteDesktopSendClipboardText =>
      'Enviar texto da área de transferência';

  @override
  String get remoteDesktopShowKeyboard => 'Mostrar teclado';

  @override
  String get remoteDesktopMoreControls => 'Mais controles';

  @override
  String get remoteDesktopUseDirectPointer => 'Usar ponteiro direto';

  @override
  String get remoteDesktopUseTouchpadPointer => 'Usar ponteiro do touchpad';

  @override
  String get remoteDesktopSendCtrlAltDelete => 'Enviar Ctrl+Alt+Delete';

  @override
  String get remoteDesktopReconnect => 'Reconectar';

  @override
  String get remoteDesktopFullScreen => 'Tela cheia';

  @override
  String get remoteDesktopCloseSession => 'Fechar sessão';

  @override
  String get remoteDesktopConnected => 'Conectado';

  @override
  String get remoteDesktopConnecting => 'Conectando';

  @override
  String get remoteDesktopReconnecting => 'Reconectando';

  @override
  String get remoteDesktopDisconnected => 'Desconectado';

  @override
  String get remoteDesktopGuideTouch => 'Touchpad';

  @override
  String get remoteDesktopGuideTouchTip =>
      'Um dedo move o ponteiro como um touchpad e um toque clica. Toque com dois dedos para clique direito, arraste com dois para rolar e faça pinça para zoom. Toque duas vezes e mantenha o dedo para arrastar.';

  @override
  String get remoteDesktopGuideKeyboardTip =>
      'Abre o teclado na tela. O que você digitar é enviado para a área de trabalho remota.';

  @override
  String get remoteDesktopGuideViewOnlyTip =>
      'Para de enviar o ponteiro e as teclas, para você olhar sem clicar por engano.';

  @override
  String get remoteDesktopGuideMoreTip =>
      'Ctrl+Alt+Del, reconectar e tela cheia ficam aqui.';

  @override
  String get remoteDesktopGuidePointerTip =>
      'Assim como o ponteiro direto, em que o dedo clica onde toca.';

  @override
  String get remoteDesktopVncClipboardLatin1Only =>
      'A área de transferência VNC só aceita texto Latin-1.';

  @override
  String get remoteDesktopAddProfile => 'Adicionar perfil';

  @override
  String get remoteDesktopNoProfiles =>
      'Nenhum perfil de área de trabalho remota';

  @override
  String get remoteDesktopAdd => 'Adicionar área de trabalho remota';

  @override
  String get remoteDesktopEdit => 'Editar área de trabalho remota';

  @override
  String get remoteDesktopTargetTip =>
      'O destino é resolvido pelo servidor SSH ou pelo agente Monitor. localhost refere-se a essa máquina.';

  @override
  String get remoteDesktopDomain => 'Domínio (opcional)';

  @override
  String get remoteDesktopPassword => 'Senha (opcional)';

  @override
  String get remoteDesktopSavePassword => 'Salvar senha';

  @override
  String get remoteDesktopSavePasswordTip =>
      'Armazenada no banco de dados criptografado. Os backups incluem senhas salvas e só são criptografados quando uma senha de backup é definida.';

  @override
  String get remoteDesktopShareSession => 'Compartilhar sessão';

  @override
  String get remoteDesktopProtocol => 'Protocolo';

  @override
  String get remoteDesktopUniqueName =>
      'Os nomes de perfil devem ser únicos para este servidor.';

  @override
  String get remoteDesktopVncPasswordLength =>
      'As senhas VNC clássicas são limitadas a 8 bytes ASCII.';

  @override
  String get remoteDesktopNameRequired => 'Informe um nome de perfil.';

  @override
  String get remoteDesktopHostRequired => 'Informe um host de destino.';

  @override
  String get remoteDesktopPortRequired => 'Informe uma porta válida.';

  @override
  String get remoteDesktopUsernameRequired =>
      'Informe o nome de usuário do RDP.';

  @override
  String get remoteDesktopVncPasswordAscii =>
      'As senhas VNC clássicas podem conter apenas caracteres ASCII.';

  @override
  String get remoteDesktopCertificateRequired =>
      'Confirmação do certificado necessária';

  @override
  String get remoteDesktopWaiting => 'Aguardando a área de trabalho…';

  @override
  String get remoteDesktopCertificateChanged =>
      'O certificado da área de trabalho remota mudou';

  @override
  String get remoteDesktopTrustCertificate => 'Confiar no certificado?';

  @override
  String get remoteDesktopCertificateChangedTip =>
      'A impressão digital do certificado não corresponde mais ao valor salvo. Verifique a nova impressão digital antes de substituir a confiança.';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      'O sistema não conseguiu verificar este certificado. Verifique a impressão digital SHA-256 antes de continuar.';

  @override
  String get remoteDesktopReplaceTrust => 'Substituir confiança';

  @override
  String get remoteDesktopTrustReconnect => 'Confiar e reconectar';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return 'Excluir o perfil de área de trabalho remota “$name”?';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return 'Reconectando ($attempt/3)…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return 'Confiança anterior\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return 'Assunto: $subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return 'Emissor: $issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return 'Válido: $start – $end';
  }

  @override
  String appearanceThemeModeLocked(String mode) {
    return 'Este tema só suporta $mode. Selecione outro tema para alterar o modo.';
  }

  @override
  String get pveAuthToken => 'Token de API';

  @override
  String get pveVersionLow =>
      'Esta funcionalidade está atualmente em fase de teste e foi testada apenas no PVE 8+. Por favor, use com cautela.';

  @override
  String get pveTokenId => 'ID do token';

  @override
  String get pveTokenSecret => 'Segredo do token';

  @override
  String get pveTokenTip =>
      'Crie um no PVE em Datacenter → Permissões → API Tokens. Ele precisa de VM.Audit, VM.PowerMgmt, VM.Console, VM.Snapshot, VM.Snapshot.Rollback, Datastore.Audit e Sys.Audit nos caminhos a mostrar; com a separação de privilégios ativa, conceda-os ao próprio token.';

  @override
  String pveTokenNoPrivileges(String account, String command) {
    return 'O token $account não pode ver nada neste host. Um token com separação de privilégios não tem as permissões do usuário; conceda-as no host PVE:\n$command\nou desmarque \"Privilege Separation\" no token.';
  }

  @override
  String pveUserNoPrivileges(String account, String command) {
    return '$account não pode ver nada neste host. Conceda permissões no host PVE:\n$command';
  }

  @override
  String get pveTokenIdInvalid =>
      'O ID do token deve ter a forma user@realm!tokenid';

  @override
  String get pvePasswordAuthTip =>
      'Entra como o usuário SSH no realm PAM, com a senha SSH, ou com a senha do PVE abaixo quando o SSH usa uma chave. Um código de dois fatores é pedido quando necessário.';

  @override
  String get pveCertUnpinned =>
      'Nenhum confirmado ainda. A menos que uma CA confiável o tenha assinado, a próxima conexão mostrará o certificado para confirmação.';

  @override
  String get pveCertForget => 'Esquecer certificado';

  @override
  String get pveCertForgetTip =>
      'A próxima conexão mostrará novamente o certificado do PVE para confirmação.';

  @override
  String get virtualization => 'Virtualização';

  @override
  String get virtIntro =>
      'Gerencie máquinas virtuais e contêineres em hosts Proxmox VE e libvirt/KVM: estado, ações de energia e consoles.';

  @override
  String get virtIntroPveMoved =>
      'O Proxmox VE saiu da página do servidor para esta aba. O cartão PVE de um servidor a abre aqui.';

  @override
  String get virtIntroLibvirt =>
      'Um servidor com o virsh do libvirt instalado aparece como host, com suas máquinas virtuais QEMU/KVM.';

  @override
  String get virtIntroTransports =>
      'Ambos funcionam por SSH, por meio de um agente Monitor ou neste dispositivo.';

  @override
  String get virtIntroTokens =>
      'O PVE pode entrar com um token de API em vez de uma senha. Configure-o na página de edição do servidor, em PVE.';

  @override
  String get virtIntroInBar => 'Ela foi adicionada à barra de abas.';

  @override
  String get virtIntroInMore =>
      'Ela está em Mais. Abas iniciais, nas configurações, pode movê-la para a barra de abas.';

  @override
  String get virtGuests => 'Máquinas virtuais';

  @override
  String get virtHosts => 'Hosts';

  @override
  String get virtCheckServer => 'Verificar este servidor';

  @override
  String get virtCheckAll => 'Verificar todos os servidores';

  @override
  String get virtProbeNotChecked => 'Ainda não verificado';

  @override
  String get virtProbeAbsent => 'Não é um host';

  @override
  String virtProbeContainer(String kind) {
    return 'Contêiner $kind';
  }

  @override
  String get virtProbeContainerTip =>
      'Este servidor roda em um contêiner, então é um convidado e não um host. Ele é gerenciado pelo host que o executa.';

  @override
  String get virtProbePve => 'PVE, não configurado';

  @override
  String virtPveSetupTip(String version) {
    return '$version está rodando neste servidor. Preencha o acesso à API nas configurações do servidor (recomenda-se um token de API) para gerenciar aqui suas máquinas virtuais e contêineres.';
  }

  @override
  String get virtNoHosts => 'Nenhum host de virtualização';

  @override
  String get virtNoHostsTip =>
      'Um servidor com Proxmox VE e acesso à API preenchido é um host, assim como um onde o virsh responde. Os outros servidores podem ser verificados no seletor de hosts.';

  @override
  String get virtNoGuests => 'Nenhuma máquina virtual ou contêiner';

  @override
  String get virtPaused => 'Pausada';

  @override
  String get virtStarting => 'Iniciando…';

  @override
  String get virtStopping => 'Parando…';

  @override
  String get virtRebooting => 'Reiniciando…';

  @override
  String get virtMigrating => 'Migrando…';

  @override
  String get virtBackingUp => 'Fazendo backup…';

  @override
  String get virtResume => 'Retomar';

  @override
  String get virtOverview => 'Visão geral';

  @override
  String get virtConsole => 'Console';

  @override
  String get virtConsoleNone =>
      'Nenhum console configurado para este convidado';

  @override
  String get virtConsoleGraphical => 'Gráfico';

  @override
  String get virtConsoleSerialTip =>
      'Abre o console serial do convidado com virsh no host. Desconectar, ou Ctrl+], volta ao shell do host.';

  @override
  String virtConsoleVia(String transport) {
    return 'via $transport';
  }

  @override
  String get virtConsoleEnterTip => 'Sem saída? Pressione Enter';

  @override
  String virtConsoleAutoEnter(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds segundos',
      one: '1 segundo',
    );
    return 'Enter será pressionado em $_temp0 para mostrar o prompt';
  }

  @override
  String get virtConsoleEnterNow => 'Agora';

  @override
  String get virtOffTip =>
      'Inicie-a para ver aqui CPU, memória, disco e rede ao vivo.';

  @override
  String get virtAllocated => 'Alocado';

  @override
  String virtRunningCount(int running, int total) {
    return '$running em execução · $total no total';
  }

  @override
  String get virtTemplate => 'Modelo';

  @override
  String get virtAutostart => 'Inicia com o host';

  @override
  String get virtErrUnreachable => 'Não foi possível acessar este host';

  @override
  String get virtErrNotConfigured =>
      'As configurações de PVE deste servidor estão incompletas';

  @override
  String get virtErrNotConfiguredTip =>
      'Verifique o endereço e a senha ou o token de API nas configurações do servidor.';

  @override
  String get virtErrAuthFailed => 'O host recusou o login';

  @override
  String get virtErrCertUnconfirmed => 'Confirme o certificado do host';

  @override
  String get virtErrCertChanged => 'O certificado do host mudou';

  @override
  String get virtErrRelayNotGranted => 'O agente Monitor não repassa conexões';

  @override
  String get virtErrExecNotGranted => 'O agente Monitor não executa comandos';

  @override
  String get virtErrNotInstalled => 'O virsh não está instalado neste servidor';

  @override
  String get virtErrServerRemoved => 'Este servidor já não existe';

  @override
  String get virtErrSudoRequired =>
      'O sudo precisa de uma senha para acessar o libvirt';

  @override
  String get virtErrSudoRejected => 'O sudo recusou a senha';

  @override
  String get virtErrInvalidResponse => 'O host respondeu de forma inesperada';

  @override
  String get virtErrActionFailed => 'O host recusou a ação';

  @override
  String get remoteSessionIdleTimeout => 'Fechar ao sair';

  @override
  String get remoteSessionIdleTimeoutTip =>
      'Por quanto tempo uma área de trabalho remota ou o console de um convidado continua conectado depois que você sai dele. Antes de fechar, um aviso dá 10 segundos para mantê-lo.';

  @override
  String get remoteSessionKeepAlive => 'Manter';

  @override
  String get remoteSessionClosedAway => 'Fechado por inatividade';

  @override
  String remoteSessionClosingIn(int seconds) {
    return 'Fecha em $seconds s';
  }

  @override
  String get reopen => 'Reabrir';

  @override
  String get virtSnapshots => 'Snapshots';

  @override
  String get virtSnapshotCreate => 'Criar snapshot';

  @override
  String get virtSnapshotNone => 'Ainda não há snapshots';

  @override
  String get virtSnapshotWithMemory => 'Discos e memória';

  @override
  String get virtSnapshotDiskOnly => 'Apenas discos';

  @override
  String get virtSnapshotParent => 'Pai';

  @override
  String get virtSnapshotRevert => 'Reverter';

  @override
  String get virtSnapshotMemory => 'Incluir memória';

  @override
  String get virtSnapshotMemoryTip =>
      'Reverter retoma o convidado a partir deste momento.';

  @override
  String get virtSnapshotMemoryAlways =>
      'Aqui, um snapshot de um convidado em execução inclui sempre a memória.';

  @override
  String get virtSnapshotMemoryOff =>
      'O convidado não está em execução, então apenas os discos são salvos.';

  @override
  String get virtSnapshotNameInvalid =>
      'Primeiro uma letra, depois letras, dígitos, - ou _; de 2 a 40 caracteres.';

  @override
  String get virtSnapshotNameTaken => 'Já existe um snapshot com este nome.';

  @override
  String get virtSnapshotRevertTip =>
      'Reverter descarta todas as alterações feitas desde o snapshot.';

  @override
  String virtSnapshotRevertAsk(String guest, String snapshot) {
    return 'Reverter $guest para $snapshot? Todas as alterações desde então serão perdidas.';
  }

  @override
  String virtSnapshotRevertStops(String guest) {
    return 'Este snapshot não tem memória: $guest será parado.';
  }

  @override
  String get virtSnapshotStartAfter => 'Iniciá-lo depois';

  @override
  String get virtVolumes => 'Volumes';

  @override
  String get virtNoPools => 'Nenhum pool de armazenamento';

  @override
  String get virtNoNetworks => 'Nenhuma rede';

  @override
  String get virtPoolInactive =>
      'O pool não está ativo, então os volumes não podem ser listados.';

  @override
  String get virtShared => 'Compartilhado entre nós';

  @override
  String get virtBackingFile => 'Arquivo base';

  @override
  String get virtNetIsolated => 'Isolada';

  @override
  String get virtNetBridged => 'Em ponte';

  @override
  String get virtNetRouted => 'Roteada';

  @override
  String get virtBridge => 'Ponte';

  @override
  String get virtPorts => 'Portas';

  @override
  String get virtAttachedGuests => 'Convidados nela';

  @override
  String get virtNoAttachedGuests => 'Nenhum convidado nela';
}
