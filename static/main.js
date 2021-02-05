var globalInstance;
const getMemory = () => globalInstance.exports.memory;

let utf8decoder = new TextDecoder();
let console_log_string = "";

let env = {
    console_log_write: (ptr, len) => {
        console_log_string += utf8decoder.decode(
            new Uint8Array(getMemory().buffer, ptr, len)
        );
    },
    console_log_flush: () => {
        console.log(console_log_string);
        console_log_string = "";
    },
    do_fetch: (ptr, len, cb, ctx) => {
        const filename = utf8decoder.decode(
            new Uint8Array(getMemory().buffer, ptr, len)
        );
        fetch(filename)
            .then((response) => response.arrayBuffer())
            .then((buffer) => new Uint8Array(buffer))
            .then((bytes) => {
                const wasm_bytes_ptr = globalInstance.exports.malloc(
                    bytes.byteLength
                );
                if (wasm_bytes_ptr == 0) throw "Null from malloc";

                const wasm_bytes = new Uint8Array(
                    getMemory().buffer,
                    wasm_bytes_ptr,
                    bytes.byteLength
                );
                wasm_bytes.set(bytes);

                globalInstance.exports._finalize_fetch(
                    cb,
                    ctx,
                    wasm_bytes_ptr,
                    bytes.byteLength
                );
            });
    },
};

fetch("zig-wasm-assets.wasm")
    .then((response) => response.arrayBuffer())
    .then((bytes) => WebAssembly.instantiate(bytes, { env }))
    .then((results) => results.instance)
    .then((instance) => {
        globalInstance = instance;

        instance.exports._start();
    });
