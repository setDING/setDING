// Serves the example songs of docs/examples under /examples/ (#923): the
// song archives (*.setDING.zip) and the other example ZIPs. The build copies
// them into dist/examples/, the dev server reads them from docs/examples, so
// they are never duplicated in the repository.
import { copyFile, mkdir, readdir, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const source = fileURLToPath(new URL('../../docs/examples/', import.meta.url));

/** The files served: every ZIP in docs/examples. */
export async function exampleFiles() {
  return (await readdir(source)).filter((f) => f.endsWith('.zip')).sort();
}

export default function examples() {
  return {
    name: 'setding-examples',
    hooks: {
      'astro:server:setup': ({ server }) => {
        server.middlewares.use('/examples/', async (req, res, next) => {
          const name = decodeURIComponent((req.url ?? '').replace(/^\/+|\?.*$/g, ''));
          if (!(await exampleFiles()).includes(name)) return next();
          res.setHeader('Content-Type', 'application/zip');
          res.end(await readFile(source + name));
        });
      },
      'astro:build:done': async ({ dir, logger }) => {
        const target = fileURLToPath(new URL('examples/', dir));
        await mkdir(target, { recursive: true });
        const files = await exampleFiles();
        for (const f of files) await copyFile(source + f, target + f);
        logger.info(`${files.length} example files in /examples/`);
      },
    },
  };
}
