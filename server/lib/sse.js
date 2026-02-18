'use strict'

/**
 * Setup an SSE (Server-Sent Events) response.
 * Returns helper functions to send events and close the stream.
 */
function createSSE(res) {
  res.setHeader('Content-Type', 'text/event-stream')
  res.setHeader('Cache-Control', 'no-cache')
  res.setHeader('Connection', 'keep-alive')
  res.setHeader('X-Accel-Buffering', 'no') // Disable nginx buffering
  res.flushHeaders()

  const send = (event, data) => {
    if (res.writableEnded) return
    if (event) res.write(`event: ${event}\n`)
    res.write(`data: ${JSON.stringify(data)}\n\n`)
  }

  const close = () => {
    if (!res.writableEnded) res.end()
  }

  return { send, close }
}

module.exports = { createSSE }
