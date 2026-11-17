// setDING website and user documentation (https://setding.app, ADR-0030).
// Swiss Standard German is the root locale, English lives under /en/. Both
// languages use the same page paths, so the language switcher finds each page.
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';

export default defineConfig({
  site: 'https://setding.app',
  // Logo and screenshots are shared with the app and the README.
  vite: { server: { fs: { allow: ['..'] } } },
  integrations: [
    starlight({
      title: 'setDING',
      logo: {
        light: '../app/branding/logo.svg',
        dark: '../app/branding/logo-dark.svg',
        replacesTitle: true,
      },
      favicon: '/favicon.svg',
      customCss: ['./src/styles/brand.css'],
      defaultLocale: 'root',
      locales: {
        root: { label: 'Deutsch', lang: 'de-CH' },
        en: { label: 'English', lang: 'en' },
      },
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/tafli/setDING' }],
      sidebar: [
        {
          label: 'Loslegen',
          translations: { en: 'Getting started' },
          items: [{ autogenerate: { directory: 'start' } }],
        },
        {
          label: 'Sets',
          translations: { en: 'Sets' },
          items: [{ autogenerate: { directory: 'sets' } }],
        },
        {
          label: 'Live-Modus',
          translations: { en: 'Live mode' },
          items: [{ autogenerate: { directory: 'live' } }],
        },
        {
          label: 'Songs',
          translations: { en: 'Songs' },
          items: [{ autogenerate: { directory: 'songs' } }],
        },
        {
          label: 'Bands und Rollen',
          translations: { en: 'Bands and roles' },
          items: [{ autogenerate: { directory: 'bands' } }],
        },
        {
          label: 'Einstellungen',
          translations: { en: 'Settings' },
          items: [{ autogenerate: { directory: 'settings' } }],
        },
      ],
      lastUpdated: false,
      plugins: [starlightLinksValidator()],
    }),
  ],
});
