// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	site: 'https://serverbox.lollipopkit.com',
	base: '/docs',
	integrations: [
		starlight({
			title: 'Server Box',
			description: 'A comprehensive cross-platform server management application built with Flutter',
			defaultLocale: 'root',
			locales: {
				root: {
					label: 'English',
					lang: 'en',
				},
				zh: {
					label: '简体中文',
					lang: 'zh-CN',
				},
			},
			logo: {
				src: './src/assets/app_icon.png',
			},
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/lollipopkit/flutter_server_box' },
			],
			sidebar: [
				{
					label: 'Getting Started',
					translations: {
						'zh-CN': '开始使用',
					},
					items: [
						{ label: 'Introduction', translations: { 'zh-CN': '介绍' }, slug: 'introduction' },
						{ label: 'Installation', translations: { 'zh-CN': '安装' }, slug: 'installation' },
						{ label: 'Quick Start', translations: { 'zh-CN': '快速开始' }, slug: 'quick-start' },
						{ label: 'Changelog', translations: { 'zh-CN': '更新日志' }, slug: 'changelog' },
					],
				},
				{
					label: 'Advanced',
					translations: {
						'zh-CN': '进阶',
					},
					items: [
						{ label: 'Monitor Agent', translations: { 'zh-CN': 'Monitor Agent' }, slug: 'advanced/monitor-agent' },
						{ label: 'Monitor Apps', translations: { 'zh-CN': 'Monitor 应用' }, slug: 'advanced/monitor-apps' },
						{ label: 'Monitor Agent Mode', translations: { 'zh-CN': 'Monitor Agent 模式' }, slug: 'advanced/monitor-agent-mode' },
						{ label: 'Monitor Settings Backup', translations: { 'zh-CN': 'Monitor 设置备份' }, slug: 'advanced/monitor-backup' },
						{ label: 'Desk Apps', translations: { 'zh-CN': 'Desk 应用' }, slug: 'advanced/monitor-desk-apps' },
						{ label: 'Workspace', translations: { 'zh-CN': '工作区' }, slug: 'advanced/workspace' },
						{ label: 'Remote Desktop', translations: { 'zh-CN': '远程桌面' }, slug: 'advanced/remote-desktop' },
						{ label: 'Agent', translations: { 'zh-CN': 'Agent' }, slug: 'advanced/agent' },
						{ label: 'Terminal on This Device', translations: { 'zh-CN': '本机终端' }, slug: 'advanced/local-terminal' },
						{ label: 'Program Status', translations: { 'zh-CN': '程序状态' }, slug: 'advanced/program-status' },
						{ label: 'BMC (Redfish)', translations: { 'zh-CN': 'BMC(Redfish)' }, slug: 'advanced/bmc' },
						{ label: 'Bulk Import Servers', translations: { 'zh-CN': '批量导入服务器' }, slug: 'advanced/bulk-import' },
						{ label: 'Widget Setup', translations: { 'zh-CN': '小组件设置' }, slug: 'advanced/widgets' },
						{ label: 'Globe View', translations: { 'zh-CN': '地球仪视图' }, slug: 'advanced/globe' },
						{ label: 'Custom Commands', translations: { 'zh-CN': '自定义命令' }, slug: 'advanced/custom-commands' },
						{ label: 'Custom Logo', translations: { 'zh-CN': '自定义 Logo' }, slug: 'advanced/custom-logo' },
						{ label: 'Links (serverbox://)', translations: { 'zh-CN': '链接(serverbox://)' }, slug: 'advanced/url-scheme' },
						{ label: 'Theme Packages', translations: { 'zh-CN': '主题包' }, slug: 'advanced/theme-packages' },
						{ label: 'JSON Settings', translations: { 'zh-CN': 'JSON 设置' }, slug: 'advanced/json-settings' },
						{ label: 'Common Issues', translations: { 'zh-CN': '常见问题' }, slug: 'advanced/troubleshooting' },
					],
				},
				{
					label: 'Development',
					translations: {
						'zh-CN': '开发',
					},
					items: [
						{ label: 'Project Structure', translations: { 'zh-CN': '项目结构' }, slug: 'development/structure' },
						{ label: 'Implementation architecture', translations: { 'zh-CN': '实现架构' }, slug: 'development/architecture' },
						{ label: 'Riverpod patterns', translations: { 'zh-CN': 'Riverpod 实践' }, slug: 'development/state' },
						{ label: 'Code Generation', translations: { 'zh-CN': '代码生成' }, slug: 'development/codegen' },
						{ label: 'Building', translations: { 'zh-CN': '构建' }, slug: 'development/building' },
						{ label: 'Testing', translations: { 'zh-CN': '测试' }, slug: 'development/testing' },
						{ label: 'Themes', translations: { 'zh-CN': '主题' }, slug: 'development/themes' },
						{ label: 'Monitor Apps', translations: { 'zh-CN': 'Monitor 应用' }, slug: 'development/monitor-apps' },
						{ label: 'Desk Apps', translations: { 'zh-CN': 'Desk 应用' }, slug: 'development/desk-apps' },
					],
				},
				// Its own entry rather than a line in a group: the app links
				// straight to it from the diagnostics setting and from the
				// intro page that asks the question, so it has to be findable
				// without knowing which section it would belong to.
				{ label: 'Privacy Policy', translations: { 'zh-CN': '隐私政策' }, slug: 'privacy' },
			],
			customCss: ['./src/styles/custom.css'],
		}),
	],
});
