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
						{ label: 'Docker Management', slug: 'features/docker' },
						{ label: 'Process & Services', slug: 'features/process' },
						{ label: 'Command Snippets', slug: 'features/snippets' },
						{ label: 'Network Tools', slug: 'features/network' },
						{ label: 'PVE (Proxmox)', slug: 'features/pve' },
					],
				},
				{
					label: 'Configuration',
					items: [
						{ label: 'Server Setup', slug: 'configuration/server' },
						{ label: 'Terminal & SSH', slug: 'configuration/terminal' },
						{ label: 'SFTP File Browser', slug: 'configuration/sftp' },
						{ label: 'Jump Server', slug: 'configuration/jump-server' },
						{ label: 'Backup & Restore', slug: 'configuration/backup' },
						{ label: 'Appearance', slug: 'configuration/appearance' },
						{ label: 'Localizations', slug: 'configuration/localizations' },
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
					label: 'Advanced',
					items: [
						{ label: 'Bulk Import Servers', slug: 'advanced/bulk-import' },
						{ label: 'Widget Setup', slug: 'advanced/widgets' },
						{ label: 'Custom Commands', slug: 'advanced/custom-commands' },
						{ label: 'Custom Logo', slug: 'advanced/custom-logo' },
						{ label: 'JSON Settings', slug: 'advanced/json-settings' },
						{ label: 'Common Issues', slug: 'advanced/troubleshooting' },
					],
				},
				{
					label: 'How It Works',
					items: [
						{ label: 'Architecture', slug: 'principles/architecture' },
						{ label: 'SSH Connection', slug: 'principles/ssh' },
						{ label: 'Terminal', slug: 'principles/terminal' },
						{ label: 'SFTP', slug: 'principles/sftp' },
						{ label: 'State Management', slug: 'principles/state' },
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
