import {
    defineConfig,
    presetWind4,
    transformerDirectives,
} from 'unocss';

export default defineConfig({
    presets: [presetWind4({ preflights: { reset: false } })],
    rules: [
        [
            /^fs-(\d+(\.\d+)?(px|rem))$/,
            (matches) => ({ 'font-size': matches[1] }),
        ],
    ],
    shortcuts: {
        'bg-base': 'bg-center bg-cover bg-no-repeat',
        'flex-middle': 'flex items-center justify-center',
        'h-s-screen': 'h-100svh',
        'w-s-screen': 'w-100svw',
        'wh-s-screen': 'h-s-screen w-s-screen',
    },
    transformers: [transformerDirectives()],
});
