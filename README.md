# ExRTP
[![Hex.pm](https://img.shields.io/hexpm/v/ex_rtp.svg)](https://hex.pm/packages/ex_rtp)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/ex_rtp)
[![CI](https://img.shields.io/github/actions/workflow/status/elixir-webrtc/ex_rtp/ci.yml?logo=github&label=CI)](https://github.com/elixir-webrtc/ex_rtp/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/elixir-webrtc/ex_rtp/graph/badge.svg?token=E98NHC8B00)](https://codecov.io/gh/elixir-webrtc/ex_rtp)

Implementation of RTP protocol in Elixir. 

Implements:
- [RTP: A Transport Protocol for Real-Time Applications](https://datatracker.ietf.org/doc/html/rfc3550)
- [A General Mechanism for RTP Header Extensions](https://datatracker.ietf.org/doc/html/rfc8285)

Includes out-of-the-box support for these RTP header extensions:
- [A Real-time Transport Protocol (RTP) Header Extension for Client-to-Mixer Audio Level Indication](https://datatracker.ietf.org/doc/html/rfc6464)
- [RTP Header Extension for the RTP Control Protocol (RTCP) Source Description Items](https://datatracker.ietf.org/doc/html/rfc7941)
- [RTP Extensions for Transport-wide Congestion Control](https://datatracker.ietf.org/doc/html/draft-holmer-rmcat-transport-wide-cc-extensions-01)

Other RTP header extensions can be added by implementing the `ExRTP.Packet.Extension` behaviour.

See [documentation](https://hexdocs.pm/ex_rtp) for usage examples.

## Installation

```elixir
def deps do
  [
    {:ex_rtp, "~> 0.2.0"}
  ]
end
```

