interface Env {
  ASSETS: Fetcher;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    // Strip /tides prefix for asset lookup
    if (url.pathname.startsWith('/tides')) {
      url.pathname = url.pathname.replace(/^\/tides/, '') || '/';
    }

    return env.ASSETS.fetch(new Request(url, request));
  },
} satisfies ExportedHandler<Env>;
