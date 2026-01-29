// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	integrations: [
		starlight({
			title: 'Flutter Server Box',
			description: 'A comprehensive cross-platform server management application built with Flutter',
			defaultLocale: 'root',
			locales: {
				root: {
					label: 'English',
					lang: 'en',
				},
				zh: {
					label: '简体中文',
					lang: 'zh',
				},
				de: {
					label: 'Deutsch',
					lang: 'de',
				},
				fr: {
					label: 'Français',
					lang: 'fr',
				},
				es: {
					label: 'Español',
					lang: 'es',
				},
				ja: {
					label: '日本語',
					lang: 'ja',
				},
			},
			logo: {
				src: './src/assets/logo.svg',
			},
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/lollipopkit/flutter_server_box' },
			],
			sidebar: [
				{
					label: 'Getting Started',
					translations: {
						zh: '开始使用',
						de: 'Erste Schritte',
						fr: 'Mise en route',
						es: 'Primeros pasos',
						ja: 'はじめに',
					},
					items: [
						{ label: 'Introduction', translations: { zh: '介绍', de: 'Einführung', fr: 'Introduction', es: 'Introducción', ja: 'はじめに' }, slug: 'introduction' },
						{ label: 'Installation', translations: { zh: '安装', de: 'Installation', fr: 'Installation', es: 'Instalación', ja: 'インストール' }, slug: 'installation' },
						{ label: 'Quick Start', translations: { zh: '快速开始', de: 'Schnellstart', fr: 'Démarrage rapide', es: 'Inicio rápido', ja: 'クイックスタート' }, slug: 'quick-start' },
					],
				},
				{
					label: 'Platform Features',
					translations: {
						zh: '平台特性',
						de: 'Plattformfunktionen',
						fr: 'Fonctionnalités de la plateforme',
						es: 'Características de la plataforma',
						ja: 'プラットフォーム機能',
					},
					items: [
						{ label: 'Mobile', translations: { zh: '移动端', de: 'Mobil', fr: 'Mobile', es: 'Móvil', ja: 'モバイル' }, slug: 'platforms/mobile' },
						{ label: 'Desktop', translations: { zh: '桌面端', de: 'Desktop', fr: 'Bureau', es: 'Escritorio', ja: 'デスクトップ' }, slug: 'platforms/desktop' },
					],
				},
				{
					label: 'Advanced',
					translations: {
						zh: '进阶',
						de: 'Fortgeschritten',
						fr: 'Avancé',
						es: 'Avanzado',
						ja: '高度な設定',
					},
					items: [
						{ label: 'Bulk Import Servers', translations: { zh: '批量导入服务器', de: 'Server-Massenimport', fr: 'Importation massive de serveurs', es: 'Importación masiva de servidores', ja: 'サーバーの一括インポート' }, slug: 'advanced/bulk-import' },
						{ label: 'Widget Setup', translations: { zh: '小组件设置', de: 'Widget-Einrichtung', fr: 'Configuration du widget', es: 'Configuración de widgets', ja: 'ウィジェット設定' }, slug: 'advanced/widgets' },
						{ label: 'Custom Commands', translations: { zh: '自定义命令', de: 'Benutzerdefinierte Befehle', fr: 'Commandes personnalisées', es: 'Comandos personalizados', ja: 'カスタムコマンド' }, slug: 'advanced/custom-commands' },
						{ label: 'Custom Logo', translations: { zh: '自定义 Logo', de: 'Benutzerdefiniertes Logo', fr: 'Logo personnalisé', es: 'Logo personalizado', ja: 'カスタムロゴ' }, slug: 'advanced/custom-logo' },
						{ label: 'JSON Settings', translations: { zh: 'JSON 设置', de: 'JSON-Einstellungen', fr: 'Paramètres JSON', es: 'Ajustes JSON', ja: 'JSON 設定' }, slug: 'advanced/json-settings' },
						{ label: 'Common Issues', translations: { zh: '常见问题', de: 'Häufige Probleme', fr: 'Problèmes courants', es: 'Problemas comunes', ja: 'よくある質問' }, slug: 'advanced/troubleshooting' },
					],
				},
				{
					label: 'How It Works',
					translations: {
						zh: '工作原理',
						de: 'Wie es funktioniert',
						fr: 'Comment ça marche',
						es: 'Cómo funciona',
						ja: '仕組み',
					},
					items: [
						{ label: 'Architecture', translations: { zh: '架构', de: 'Architektur', fr: 'Architecture', es: 'Arquitectura', ja: 'アーキテクチャ' }, slug: 'principles/architecture' },
						{ label: 'SSH Connection', translations: { zh: 'SSH 连接', de: 'SSH-Verbindung', fr: 'Connexion SSH', es: 'Conexión SSH', ja: 'SSH 接続' }, slug: 'principles/ssh' },
						{ label: 'Terminal', translations: { zh: '终端', de: 'Terminal', fr: 'Terminal', es: 'Terminal', ja: 'ターミナル' }, slug: 'principles/terminal' },
						{ label: 'SFTP', translations: { zh: 'SFTP', de: 'SFTP', fr: 'SFTP', es: 'SFTP', ja: 'SFTP' }, slug: 'principles/sftp' },
						{ label: 'State Management', translations: { zh: '状态管理', de: 'Zustandsverwaltung', fr: 'Gestion d\'état', es: 'Gestión de estado', ja: '状態管理' }, slug: 'principles/state' },
					],
				},
				{
					label: 'Development',
					translations: {
						zh: '开发',
						de: 'Entwicklung',
						fr: 'Développement',
						es: 'Desarrollo',
						ja: '開発',
					},
					items: [
						{ label: 'Project Structure', translations: { zh: '项目结构', de: 'Projektstruktur', fr: 'Structure du projet', es: 'Estructura del proyecto', ja: 'プロジェクト構造' }, slug: 'development/structure' },
						{ label: 'Architecture', translations: { zh: '架构', de: 'Architektur', fr: 'Architecture', es: 'Arquitectura', ja: 'アーキテクチャ' }, slug: 'development/architecture' },
						{ label: 'State Management', translations: { zh: '状态管理', de: 'Zustandsverwaltung', fr: 'Gestion d\'état', es: 'Gestión de estado', ja: '状態管理' }, slug: 'development/state' },
						{ label: 'Code Generation', translations: { zh: '代码生成', de: 'Code-Generierung', fr: 'Génération de code', es: 'Generación de código', ja: 'コード生成' }, slug: 'development/codegen' },
						{ label: 'Building', translations: { zh: '构建', de: 'Bauen', fr: 'Construction', es: 'Construcción', ja: 'ビルド' }, slug: 'development/building' },
						{ label: 'Testing', translations: { zh: '测试', de: 'Testen', fr: 'Tests', es: 'Pruebas', ja: 'テスト' }, slug: 'development/testing' },
					],
				},
			],
			customCss: ['./src/styles/custom.css'],
		}),
	],
});
