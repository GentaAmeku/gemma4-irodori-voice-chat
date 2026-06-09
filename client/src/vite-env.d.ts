/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_GIC_DEFAULT_BASE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
