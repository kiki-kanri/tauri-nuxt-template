// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
    app: {
        head: {
            title: 'app-name-placeholder',
            titleTemplate: '%s｜app-name-placeholder',
        },
        keepalive: false,
    },
    compatibilityDate: '2100-01-01',
    css: ['@/assets/scss/index.scss'],
    devServer: {
        host: process.env.DEV_SERVER_HOST,
        port: Number(process.env.DEV_SERVER_PORT) || undefined,
    },
    experimental: {
        asyncContext: true,
        browserDevtoolsTiming: true,
        extractAsyncDataHandlers: true,
        navigationRepaint: true,
        typescriptPlugin: true,
        // viewTransition: true,
        watcher: 'parcel',
    },
    ignore: ['**/src-tauri/**'],
    kikiutilsNuxt: { enabledModules: { robots: false } },
    modules: ['@kikiutils/nuxt'],
    ssr: false,
    unfonts: {
        google: {
            families: [
                {
                    name: 'Noto+Sans+TC',
                    styles: 'wght@100..900',
                },
            ],
        },
        inlineFontFace: false,
    },
    vite: {
        clearScreen: false,
        envPrefix: [
            'TAURI_',
            'VITE_',
        ],
        server: {
            allowedHosts: (process.env.DEV_VITE_SERVER_ALLOWED_HOSTS || '').split(','),
            strictPort: true,
        },
    },
});
