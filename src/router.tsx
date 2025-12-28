import { createRouter, createRootRoute, createRoute, Outlet } from '@tanstack/react-router'
import { HomePage } from '@/pages/home'
import { TidesPage } from '@/pages/tides'

const rootRoute = createRootRoute({
  component: () => <Outlet />,
})

const homeRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/',
  component: HomePage,
})

const tidesRoute = createRoute({
  getParentRoute: () => rootRoute,
  path: '/tides',
  component: TidesPage,
})

const routeTree = rootRoute.addChildren([homeRoute, tidesRoute])

export const router = createRouter({ routeTree })

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router
  }
}
