import type { Metadata } from 'next'
import { Analytics } from '@vercel/analytics/next'
import { SpeedInsights } from '@vercel/speed-insights/next'
import './globals.css'
import './arcade.css'
import { ThemeProvider } from '@/components/ThemeProvider'

export const metadata: Metadata = {
  title: 'PIXELARIOUS',
  description: '1인 개발자 LeeDoik이 만든 게임과 소프트웨어를 직접 만나보는 네온 오락실',
}

const themeInit =
  "try{if(localStorage.getItem('palette')==='dmg')document.body.classList.add('dmg')}catch(e){}"

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body suppressHydrationWarning>
        <script dangerouslySetInnerHTML={{ __html: themeInit }} />
        <ThemeProvider>{children}</ThemeProvider>
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  )
}
