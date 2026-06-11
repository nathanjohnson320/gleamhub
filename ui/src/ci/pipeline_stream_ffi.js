export function subscribe(url, token, on_data, on_error) {
  const controller = new AbortController();
  let closed = false;

  const finish = (err) => {
    if (closed) {
      return;
    }
    closed = true;
    if (err && err.name !== "AbortError") {
      on_error();
    }
  };

  fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
    signal: controller.signal,
  })
    .then((response) => {
      if (!response.ok || !response.body) {
        finish(new Error(`HTTP ${response.status}`));
        return;
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";

      const pump = () => {
        reader
          .read()
          .then(({ done, value }) => {
            if (closed) {
              return;
            }
            if (done) {
              finish(new Error("stream ended"));
              return;
            }
            buffer += decoder.decode(value, { stream: true });
            let boundary = buffer.indexOf("\n\n");
            while (boundary !== -1) {
              const block = buffer.slice(0, boundary);
              buffer = buffer.slice(boundary + 2);
              const data = parse_sse_data(block);
              if (data !== null) {
                on_data(data);
              }
              boundary = buffer.indexOf("\n\n");
            }
            pump();
          })
          .catch((err) => {
            finish(err);
          });
      };

      pump();
    })
    .catch((err) => {
      finish(err);
    });

  return () => {
    closed = true;
    controller.abort();
  };
}

function parse_sse_data(block) {
  const lines = block.split("\n");
  let data = "";
  for (const line of lines) {
    if (line.startsWith("data:")) {
      const chunk = line.startsWith("data: ")
        ? line.slice(6)
        : line.slice(5);
      data = data === "" ? chunk : `${data}\n${chunk}`;
    }
  }
  return data === "" ? null : data;
}
