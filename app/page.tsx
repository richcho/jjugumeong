export const dynamic = "force-static";

export default function Home() {
  return (
    <main>
      <img alt="" height="144" src="/game/index.144x144.png" width="144" />
      <h1>쥐구멍</h1>
      <p>아이패드용 게임을 불러오는 중입니다.</p>
      <a href="/game/index.html">게임 시작</a>
      <script
        dangerouslySetInnerHTML={{
          __html: 'window.location.replace("/game/index.html");',
        }}
      />
    </main>
  );
}
