// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
// 
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
import socket from "./socket"

var channel = null;

let backend_url = document.getElementById('backend_url');

let public_key = document.getElementById('public_key');
let backend_params = document.getElementById('backend_params');
let start_backend_btn = document.getElementById('start_backend_btn');

let leave_btn = document.getElementById('leave_btn');


let connection_status = document.getElementById('connection-status');

let sign_btn = document.getElementById('sign_btn');
let sign_msg = document.getElementById('sign_msg');
let sign_mthd = document.getElementById('sign_mthd');
let abort_btn = document.getElementById('abort_btn');
let abort_code = document.getElementById('abort_code');

let transfer_btn = document.getElementById('transfer_btn');
let tranfer_amount = document.getElementById('transfer_amount');

let connect_btn = document.getElementById('connect_btn');
// let connect_responder_btn = document.getElementById('connect_responder_btn');

let query_funds_btn = document.getElementById('query_funds_btn');
let shutdown_btn = document.getElementById('shutdown_btn');
let teardown_btn = document.getElementById('teardown_btn');

let provide_hash_call_contract_btn = document.getElementById('provide_hash_call_contract_btn');
let provide_hash_contract_amount = document.getElementById('provide_hash_contract_amount');

let reveal_contract_amount = document.getElementById('reveal_contract_amount');
let reveal_call_contract_btn = document.getElementById('reveal_call_contract_btn');

let contract_method = document.getElementById('contract_method');
let contract_params = document.getElementById('contract_params');
let contract_amount = document.getElementById('contract_amount');
let call_contract_btn = document.getElementById('call_contract_btn');
let query_contract_btn = document.getElementById('query_contract_btn');

// let bet_amount = document.getElementById('bet_amount');
// let coin_guess = document.getElementById('coin_guess');

let connect_port = document.getElementById('connect_port');
let channel_id = document.getElementById('channel_id');


let connect_initiator_websocket_btn = document.getElementById('connect_initiator_websocket_btn');
let connect_responder_websocket_btn = document.getElementById('connect_responder_websocket_btn');

let ul = document.getElementById('msg-list');        // list of messages.
let name = document.getElementById('name');          // name of message sender

// "listen" for the [Enter] keypress event to send a message:
// msg.addEventListener('keypress', function (event) {
//     if (event.keyCode == 13 && msg.value.length > 0) { // don't sent empty msg.
//         channel.push('log_event', { // send the message to the server on "shout" channel
//             name: name.value,     // get value of "name" of person sending the message
//             message: msg.value    // get message text (value) from msg input field.
//         });
//         msg.value = '';         // reset the message input field for next message.
//     }
// });

function encodeQueryData(data) {
    const ret = [];
    for (let d in data)
        if (data[d] != "") {
            ret.push(encodeURIComponent(d) + '=' + encodeURIComponent(data[d]));
        }
    return ret.join('&');
}

function updateBackendParams(host, port, channel_id, public_account) {
    var params = encodeQueryData({ port: port, existing_channel_id: channel_id, initiator_id: public_account })
    backend_params.value = backend_url.value.concat("?", params)
}

backend_url.addEventListener('input', function (updatevalue) {
    updateBackendParams(backend_url.value, connect_port.value, channel_id.value, public_key.value)
});

connect_port.addEventListener('input', function (updatevalue) {
    updateBackendParams(backend_url.value, connect_port.value, channel_id.value, public_key.value)
});

channel_id.addEventListener('change', function (updatevalue) {
    updateBackendParams(backend_url.value, connect_port.value, channel_id.value, public_key.value)
});

channel_id.addEventListener('input', function (updatevalue) {
    if (channel_id.value == "") {
        connect_btn.textContent = "Connect"
    } else {
        connect_btn.textContent = "Reestablish"
    }
    updateBackendParams(backend_url.value, connect_port.value, channel_id.value, public_key.value)
});

public_key.addEventListener('input', function (updatevalue) {
    updateBackendParams(backend_url.value, connect_port.value, channel_id.value, public_key.value)
});

function httpGet(theUrl) {
    var xmlHttp = new XMLHttpRequest();
    xmlHttp.open("GET", theUrl);
    xmlHttp.send();
    // coors issue, return is not logged as expected.
    xmlHttp.onload = function () {
        let responseObj = xmlHttp.response;
        console.log(responseObj)
    };
}

start_backend_btn.addEventListener('click', function (event) {
    console.log(httpGet(backend_params.value))
});

sign_btn.addEventListener('click', function (event) {
    channel.push('sign', { // send the message to the server on "shout" channel
        method: sign_mthd.value,     // get value of "name" of person sending the message
        to_sign: sign_msg.value    // get message text (value) from msg input field.
    });
    sign_mthd.value = '';
    sign_msg.value = '';
});

abort_btn.addEventListener('click', function (event) {
    channel.push('abort', { // send the message to the server on "shout" channel
        method: sign_mthd.value,     // get value of "name" of person sending the message
        abort_code: parseInt(abort_code.value)
    });
    sign_mthd.value = '';
    sign_msg.value = '';
});

shutdown_btn.addEventListener('click', function (event) {
    channel.push('shutdown', {});
});

query_funds_btn.addEventListener('click', function (event) {
    channel.push('query_funds', {});
});

transfer_btn.addEventListener('click', function (event) {
    channel.push('transfer', { // send the message to the server on "shout" channel
        amount: parseInt(tranfer_amount.value),     // get value of "name" of person sending the message
    });
});

connect_btn.addEventListener('click', function (event) {
    channel.push('connect/reestablish', { port: parseInt(connect_port.value), channel_id: channel_id.value });
});

leave_btn.addEventListener('click', function (event) {
    channel.push('leave', {});
});

teardown_btn.addEventListener('click', function (event) {
    channel.push('teardown', {});
});

call_contract_btn.addEventListener('click', function (event) {
    channel.push('call_contract', { contract_amount: parseInt(contract_amount.value), contract_params: contract_params.value, contract_method: contract_method.value })
});

provide_hash_call_contract_btn.addEventListener('click', function (event) {
    channel.push('provide_hash_call_contract', { contract_amount: parseInt(provide_hash_contract_amount.value) })
});

reveal_call_contract_btn.addEventListener('click', function (event) {
    channel.push('reveal_call_contract', {})
});

query_contract_btn.addEventListener('click', function (event) {
    channel.push('query_contract', { contract_method: contract_method.value })
});


connect_initiator_websocket_btn.addEventListener('click', function (event) {

    channel = socket.channel('socket_connector:lobby', { role: "initiator" }); // connect to chat "room"

    channel.join()
        .receive("ok", function (resp) {
            console.log("Joined successfully", resp)
            connect_btn.disabled = false
        })
        .receive("error", resp => { console.log("Unable to join", resp) });


    channel.on('log_event', function (payload) { // listen to the 'log_event' event
        let li = document.createElement("li"); // create new list item DOM element
        let name = payload.name || 'guest';    // get name from payload or set default
        li.innerHTML = '<b>' + name + '</b>: ' + payload.message; // set li contents
        ul.prepend(li);                    // append to list
    });

    channel.on('sign_approve', function (payload) {
        sign_msg.value = payload.to_sign
        sign_mthd.value = payload.method
    });

    channel.on('channels_info', function (payload) {
        channel_id.value = payload.channel_id
        connect_btn.textContent = "Reestablish"
        var event = new Event('input');
        channel_id.dispatchEvent(event);
    });

    channel.on('connected', function (payload) {
        connection_status.style.backgroundColor = 'green';
    });

    channel.on('disconnected', function (payload) {
        connection_status.style.backgroundColor = 'red';
    });
});


connect_responder_websocket_btn.addEventListener('click', function (event) {

    channel = socket.channel('socket_connector:lobby', { role: "responder", channel_id: channel_id.value }); // connect to chat "room"

    channel.join()
        .receive("ok", function (resp) {
            console.log("Joined successfully", resp)
            connect_btn.disabled = false
        })
        .receive("error", resp => { console.log("Unable to join", resp) });

    channel.on('log_event', function (payload) { // listen to the 'log_event' event
        console.log("some message");
        let li = document.createElement("li"); // create new list item DOM element
        let name = payload.name || 'guest';    // get name from payload or set default
        li.innerHTML = '<b>' + name + '</b>: ' + payload.message; // set li contents
        ul.prepend(li);                    // append to list
    });

    channel.on('sign_approve', function (payload) {
        sign_msg.value = payload.to_sign
        sign_mthd.value = payload.method
    });

    channel.on('channels_info', function (payload) {
        channel_id.value = payload.channel_id
        connect_btn.textContent = "Reestablish"
        var event = new Event('input');
        channel_id.dispatchEvent(event);
    });

    channel.on('connected', function (payload) {
        connection_status.style.backgroundColor = 'green';
    });

    channel.on('disconnected', function (payload) {
        connection_status.style.backgroundColor = 'red';
    });
});

updateBackendParams(backend_url.value, connect_port.value, channel_id.value, public_key.value)
connect_btn.disabled = true