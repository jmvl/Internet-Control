import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'Internet Control Infrastructure',
  tagline: 'Enterprise-grade home network infrastructure with multi-layer traffic control',
  favicon: 'img/favicon.ico',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  url: 'https://your-docusaurus-site.example.com',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'internet-control', // Usually your GitHub org/user name.
  projectName: 'internet-control-docs', // Usually your repo name.

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/facebook/docusaurus/tree/main/packages/create-docusaurus/templates/shared/',
        },
        blog: {
          showReadingTime: true,
          feedOptions: {
            type: ['rss', 'atom'],
            xslt: true,
          },
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/facebook/docusaurus/tree/main/packages/create-docusaurus/templates/shared/',
          // Useful options to enforce blogging best practices
          onInlineTags: 'warn',
          onInlineAuthors: 'warn',
          onUntruncatedBlogPosts: 'warn',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    image: 'img/docusaurus-social-card.jpg',
    navbar: {
      title: 'Internet Control Infrastructure',
      logo: {
        alt: 'Infrastructure Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {to: '/blog', label: 'Updates', position: 'left'},
        {
          href: 'https://github.com/your-org/internet-control',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Infrastructure',
          items: [
            {
              label: 'Network Architecture',
              to: '/docs/architecture',
            },
            {
              label: 'Traffic Control',
              to: '/docs/openwrt/openwrt-time-based-throttling-guide',
            },
            {
              label: 'Container Platform',
              to: '/docs/docker/overview',
            },
          ],
        },
        {
          title: 'Services',
          items: [
            {
              label: 'OPNsense Firewall',
              to: '/docs/OPNsense/',
            },
            {
              label: 'Supabase Platform',
              to: '/docs/Supabase/supabase-readme',
            },
            {
              label: 'GitLab DevOps',
              to: '/docs/gitlab/pct-501-gitlab-setup',
            },
          ],
        },
        {
          title: 'Management',
          items: [
            {
              label: 'Monitoring',
              to: '/docs/uptime-kuma/uptime-kuma-installation',
            },
            {
              label: 'Email Services',
              to: '/docs/hestia/',
            },
            {
              label: 'GitHub',
              href: 'https://github.com/your-org/internet-control',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Internet Control Infrastructure Documentation.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'yaml', 'json', 'nginx'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
