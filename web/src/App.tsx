import { useEffect, useState } from "react";

type Status = "checking" | "ok" | "down";

function App() {
  const [status, setStatus] = useState<Status>("checking");

  useEffect(() => {
    fetch("/healthz")
      .then((res) => setStatus(res.ok ? "ok" : "down"))
      .catch(() => setStatus("down"));
  }, []);

  return (
    <main>
      <h1>Pet Search</h1>
      <p>API status: {status}</p>
    </main>
  );
}

export default App;
