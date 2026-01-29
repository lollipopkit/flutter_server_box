// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

// https://astro.build/config
export default defineConfig({
	integrations: [
		starlight({
			title: 'Flutter Server Box',
			description: 'A comprehensive cross-platform server management application built with Flutter',
			logo: {
				src: './src/assets/logo.svg',
			},
			social: [
				{ icon: 'github', label: 'GitHub', href: 'https://github.com/lollipopkit/flutter_server_box' },
			],
			sidebar: [
				{
					label: 'Getting Started',
					items: [
						{ label: 'Introduction', slug: 'introduction' },
						{ label: 'Installation', slug: 'installation' },
						{ label: 'Quick Start', slug: 'quick-start' },
					],
				},
				{
					label: 'Features',
					items: [
						{ label: 'Server Monitoring', slug: 'features/monitoring' },
						{ label: 'SSH Terminal', slug: 'features/ssh' },
						{ label: 'SFTP File Browser', slug: 'features/sftp' },
						{ label: 'Docker Management', slug: 'features/docker' },
						{ label: 'Process & Services', slug: 'features/process' },
						{ label: 'Snippets', slug: 'features/snippets' },
						{ label: 'Network Tools', slug: 'features/network' },
						{ label: 'PVE (Proxmox)', slug: 'features/pve' },
					],
				},
				{
					label: 'Platform Features',
					items: [
						{ label: 'Mobile', slug: 'platforms/mobile' },
						{ label: 'Desktop', slug: 'platforms/desktop' },
						{ label: 'watchOS', slug: 'platforms/watchos' },
					],
				},
				{
					label: 'Configuration',
					items: [
						{ label: 'Server Setup', slug: 'configuration/server' },
						{ label: 'SSH Keys', slug: 'configuration/ssh-keys' },
						{ label: 'Terminal Settings', slug: 'configuration/terminal' },
						{ label: 'SFTP Settings', slug: 'configuration/sftp' },
						{ label: 'Editor Settings', slug: 'configuration/editor' },
						{ label: 'Jump Server', slug: 'configuration/jump-server' },
						{ label: 'Backup & Restore', slug: 'configuration/backup' },
						{ label: 'Appearance', slug: 'configuration/appearance' },
						{ label: 'Localizations', slug: 'configuration/localizations' },
					],
				},
				{
					label: 'Advanced Configuration',
					items: [
						{ label: 'Custom Logo', slug: 'advanced/custom-logo' },
						{ label: 'Custom Commands', slug: 'advanced/custom-commands' },
						{ label: 'Bulk Import', slug: 'advanced/bulk-import' },
						{ label: 'JSON Settings', slug: 'advanced/json-settings' },
						{ label: 'SSH Virtual Keys', slug: 'advanced/virtual-keys' },
						{ label: 'Widget Setup', slug: 'advanced/widgets' },
						{ label: 'Troubleshooting', slug: 'advanced/troubleshooting' },
					],
				},
				{
					label: 'About Principles',
					items: [
						{ label: 'Architecture Overview', slug: 'principles/architecture' },
						{ label: 'SSH Connection', slug: 'principles/ssh' },
						{ label: 'Terminal Implementation', slug: 'principles/terminal' },
						{ label: 'SFTP System', slug: 'principles/sftp' },
						{ label: 'State Management', slug: 'principles/state' },
						{ label: 'Data Persistence', slug: 'principles/storage' },
					],
				},
				{
					label: 'Development',
					items: [
						{ label: 'Project Structure', slug: 'development/structure' },
						{ label: 'Architecture', slug: 'development/architecture' },
						{ label: 'State Management', slug: 'development/state' },
						{ label: 'Code Generation', slug: 'development/codegen' },
						{ label: 'Building', slug: 'development/building' },
						{ label: 'Testing', slug: 'development/testing' },
					],
				},
			],
			customCss: ['./src/styles/custom.css'],
		}),
	],
});
