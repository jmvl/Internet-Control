import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.
 */
const sidebars: SidebarsConfig = {
  tutorialSidebar: [
    'intro',
    {
      type: 'category',
      label: 'Infrastructure Overview',
      items: [
        'infrastructure',
        'architecture',
        'quick-start',
        'emergency-quick-start',
        'prd',
      ],
    },
    {
      type: 'category',
      label: 'Network Components',
      items: [
        {
          type: 'category',
          label: 'OpenWrt',
          items: [
            'openwrt/openwrt-time-based-throttling-guide',
            'openwrt/wifi-throttling-setup',
            'openwrt/backup-wifi-setup',
            'openwrt/2025-09-08-openwrt-maintenance',
            'openwrt/scripts/CHANGES_REVIEW',
          ],
        },
        {
          type: 'category',
          label: 'OPNsense',
          items: [
            'OPNsense/index',
            'OPNsense/OPNsense_setup',
            'OPNsense/DEPLOYMENT_INSTRUCTIONS',
          ],
        },
        'networking/index',
        {
          type: 'category',
          label: 'Docker Platform',
          items: [
            'docker/overview',
            'docker/containers-overview',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'Application Services',
      items: [
        {
          type: 'category',
          label: 'Supabase',
          items: [
            'Supabase/supabase-readme',
            'Supabase/supabase-quick-install',
            'Supabase/macos-localhost-install',
            'Supabase/openai-api-key-setup',
            'Supabase/2024-09-08-supabase-maintenance',
          ],
        },
        {
          type: 'category',
          label: 'GitLab',
          items: [
            'gitlab/pct-501-gitlab-setup',
            'gitlab/gitlab-migration-plan',
            'gitlab/gitlab-upgrade-status-report',
          ],
        },
        {
          type: 'category',
          label: 'Automation & Monitoring',
          items: [
            'uptime-kuma/uptime-kuma-installation',
          ],
        },
        {
          type: 'category',
          label: 'Email Services',
          items: [
            'hestia/index',
            'hestia/spamhaus-blacklist-resolution',
          ],
        },
        {
          type: 'category',
          label: 'Media Services',
          items: [
            'immich/immich-installation',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'Tutorials',
      items: [
        'tutorial-basics/create-a-document',
        'tutorial-basics/create-a-blog-post',
        'tutorial-basics/markdown-features',
        'tutorial-basics/deploy-your-site',
        'tutorial-basics/congratulations',
      ],
    },
    {
      type: 'category',
      label: 'Advanced',
      items: [
        'tutorial-extras/manage-docs-versions',
        'tutorial-extras/translate-your-site',
      ],
    },
  ],
};

export default sidebars;
