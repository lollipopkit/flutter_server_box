// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
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
					lang: 'zh',
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
					},
					items: [
						{ label: 'Introduction', translations: { zh: '介绍' }, slug: 'introduction' },
						{ label: 'Installation', translations: { zh: '安装' }, slug: 'installation' },
						{ label: 'Quick Start', translations: { zh: '快速开始' }, slug: 'quick-start' },
					],
				},
				{
					label: 'Platform Features',
					translations: {
						zh: '平台特性',
					},
					items: [
						{ label: 'Mobile', translations: { zh: '移动端' }, slug: 'platforms/mobile' },
						{ label: 'Desktop', translations: { zh: '桌面端' }, slug: 'platforms/desktop' },
					],
				},
				{
					label: 'Advanced',
					translations: {
						zh: '进阶',
					},
					items: [
						{ label: 'Monitor Agent', translations: { zh: 'Monitor Agent' }, slug: 'advanced/monitor-agent' },
						{ label: 'Agent', translations: { zh: 'Agent' }, slug: 'advanced/agent' },
						{ label: 'Terminal on This Device', translations: { zh: '本机终端' }, slug: 'advanced/local-terminal' },
						{ label: 'Bulk Import Servers', translations: { zh: '批量导入服务器' }, slug: 'advanced/bulk-import' },
						{ label: 'Widget Setup', translations: { zh: '小组件设置' }, slug: 'advanced/widgets' },
						{ label: 'Custom Commands', translations: { zh: '自定义命令' }, slug: 'advanced/custom-commands' },
						{ label: 'Custom Logo', translations: { zh: '自定义 Logo' }, slug: 'advanced/custom-logo' },
						{ label: 'JSON Settings', translations: { zh: 'JSON 设置' }, slug: 'advanced/json-settings' },
						{ label: 'Common Issues', translations: { zh: '常见问题' }, slug: 'advanced/troubleshooting' },
					],
				},
				{
					label: 'How It Works',
					translations: {
						zh: '工作原理',
					},
					items: [
						{ label: 'Architecture', translations: { zh: '架构' }, slug: 'principles/architecture' },
						{ label: 'SSH Connection', translations: { zh: 'SSH 连接' }, slug: 'principles/ssh' },
						{ label: 'Terminal', translations: { zh: '终端' }, slug: 'principles/terminal' },
						{ label: 'SFTP', translations: { zh: 'SFTP' }, slug: 'principles/sftp' },
						{ label: 'State Management', translations: { zh: '状态管理' }, slug: 'principles/state' },
					],
				},
				{
					label: 'Development',
					translations: {
						zh: '开发',
					},
					items: [
						{ label: 'Project Structure', translations: { zh: '项目结构' }, slug: 'development/structure' },
						{ label: 'Architecture', translations: { zh: '架构' }, slug: 'development/architecture' },
						{ label: 'State Management', translations: { zh: '状态管理' }, slug: 'development/state' },
						{ label: 'Code Generation', translations: { zh: '代码生成' }, slug: 'development/codegen' },
						{ label: 'Building', translations: { zh: '构建' }, slug: 'development/building' },
						{ label: 'Testing', translations: { zh: '测试' }, slug: 'development/testing' },
					],
				},
			],
			customCss: ['./src/styles/custom.css'],
		}),
	],
});
