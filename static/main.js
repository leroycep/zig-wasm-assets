var globalInstance;
const getMemory = () => globalInstance.exports.memory;
const getMemU32 = (ptr) => new Uint32Array(getMemory().buffer, ptr, 1)[0];

let utf8encoder = new TextEncoder();
let utf8decoder = new TextDecoder();
let console_log_string = "";

var js_promises = {};
var open_js_promise_ids = [];

class NotFoundError extends Error {
    constructor() {
        super("File not found");
        this.name = "NotFoundError";
    }
}
class OutOfMemoryError extends Error {
    constructor() {
        super("Out of memory");
        this.name = "OutOfMemoryError";
    }
}

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
            .then((response) => {
                if (!response.ok) {
                    throw new NotFoundError();
                }
                return response.arrayBuffer();
            })
            .then((buffer) => new Uint8Array(buffer))
            .then(
                (bytes) => {
                    const wasm_bytes_ptr = globalInstance.exports.malloc(
                        bytes.byteLength
                    );
                    if (wasm_bytes_ptr == 0) throw new OutOfMemoryError();

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
                },
                (err) => {
                    if (err instanceof OutOfMemoryError) {
                        globalInstance.exports._fail_fetch(cb, ctx, getMemU32(globalInstance.exports.ERROR_OUT_OF_MEMORY));
                    } else {
                        globalInstance.exports._fail_fetch(cb, ctx, getMemU32(globalInstance.exports.ERROR_NOT_FOUND));
                    }
                }
            );
    },
    reject_promise: (id, errno) => {
        js_promises[id].reject(errno);
        open_js_promise_ids.push(id);
        delete js_promises[id];
    },
    resolve_promise: (id, ptr, len) => {
        const res = utf8decoder.decode(
            new Uint8Array(getMemory().buffer, ptr, len)
        );
        js_promises[id].resolve(res);
        open_js_promise_ids.push(id);
        delete js_promises[id];
    },
};

function getReversed(filename) {
    const filename_encoded = utf8encoder.encode(filename);

    const wasm_bytes_ptr = globalInstance.exports.malloc(
        filename_encoded.byteLength
    );
    if (wasm_bytes_ptr == 0) throw "Null from malloc";

    const wasm_bytes = new Uint8Array(
        getMemory().buffer,
        wasm_bytes_ptr,
        filename_encoded.byteLength
    );
    wasm_bytes.set(filename_encoded);

    return new Promise((resolve, reject) => {
        let id = Object.keys(js_promises).length;
        if (open_js_promise_ids.length > 0) {
            id = open_js_promise_ids.pop();
        }
        js_promises[id] = { resolve, reject };
        globalInstance.exports.reverse_file(
            id,
            wasm_bytes_ptr,
            filename_encoded.byteLength
        );
    });
}

function getErrorName(errno) {
    const ptr = globalInstance.exports.error_name_ptr(errno);
    const len = globalInstance.exports.error_name_len(errno);
    return utf8decoder.decode(
        new Uint8Array(getMemory().buffer, ptr, len)
    );
}

fetch("zig-wasm-assets.wasm")
    .then((response) => response.arrayBuffer())
    .then((bytes) => WebAssembly.instantiate(bytes, { env }))
    .then((results) => results.instance)
    .then((instance) => {
        globalInstance = instance;

        instance.exports.init();
        var interval = null;
        interval = window.setInterval(instance.exports.update, 1000);

        getReversed("stuff.txt").then(
            (reversed_string) => {
                console.log("Got reversed string! ", reversed_string);
            },
            (errno) => {
                console.error("Failed to reverse 'stuff.txt':", getErrorName(errno));
            }
        );
        getReversed("world.txt").then(
            (reversed_string) => {
                console.log("Got reversed string! ", reversed_string);
            },
            (errno) => {
                console.error("Failed to reverse 'world.txt':", getErrorName(errno));
            }
        );
    });
