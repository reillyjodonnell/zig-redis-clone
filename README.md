## Redis clone with zig

https://github.com/reillyjodonnell/zig-redis-clone/assets/65147216/a60657a5-184a-4430-bfde-a803a6479fc9

### How Redis works

- "In memory db" means that it's literally just a hash map that reads/ updates/ deletes values at run time as they come in

### How is this implemented?

1. Create a TCP server bounded to a specific port (and address) and listen for incoming stream
2. convert stream into a string
3. Parse string into tokens
4. Interact with cache through generated tokens to update it
5. return a response to the stream

## How to run

`zig run main.zig`

then interact with database with netcat
i.e. `nc 127.0.0.1 8080`

## Common errors:

`.ADDRINUSE => return error.AddressInUse,`
This means the port & IP you've got is being used. You can either:

1. Choose a different port
2. Kill the process running at that port:
   - `lsof -i :8080`
   - `kill 1234` (or whatever the id from above is)
