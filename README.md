# ExRTP
[![Hex.pm](https://img.shields.io/hexpm/v/ex_rtp.svg)](https://hex.pm/packages/ex_rtp)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/ex_rtp)
[![CI](https://img.shields.io/github/actions/workflow/status/elixir-webrtc/ex_rtp/ci.yml?logo=github&label=CI)](https://github.com/elixir-webrtc/ex_rtp/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/elixir-webrtc/ex_rtp/graph/badge.svg?token=E98NHC8B00)](https://codecov.io/gh/elixir-webrtc/ex_rtp)

Implementation of RTP protocol in Elixir. 

Implements:
- [RFC 3550 - RTP: A Transport Protocol for Real-Time Applications](https://datatracker.ietf.org/doc/html/rfc3550)
- [RFC 5285 - A General Mechanism for RTP Header Extensions](https://datatracker.ietf.org/doc/html/rfc5285)

## Installation

```elixir
def deps do
  [
    {:ex_rtp, "~> 0.2.0"}
  ]
end
```

