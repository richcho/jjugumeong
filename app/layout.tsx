import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "쥐구멍",
  description: "작은 쥐구멍에서 시작하는 2D 방치형 문명 성장 게임",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ko">
      <body>{children}</body>
    </html>
  );
}
