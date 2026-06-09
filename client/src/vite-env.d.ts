/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_GIC_BASE_URL_STORAGE_KEY?: string;
  readonly VITE_GIC_DEFAULT_BASE_URL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
