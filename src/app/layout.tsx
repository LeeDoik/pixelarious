import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'NEO_KIDO',
  description: '1인 개발자 LeeDoik의 게임을 브라우저에서 바로 플레이하는 픽셀 아케이드',
}

const themeInit =
  "try{if(localStorage.getItem('palette')==='dmg')document.body.classList.add('dmg')}catch(e){}"

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ko">
      <body suppressHydrationWarning>
        <script dangerouslySetInnerHTML={{ __html: themeInit }} />
        {children}
      </body>
    </html>
  )
}
