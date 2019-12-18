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

let channel = socket.channel('socket_connector:lobby', {}); // connect to chat "room"
let my_button = document.getElementById('my-button');
let msg = document.getElementById('msg');            // message input field

channel.on('shout', function (payload) { // listen to the 'shout' event
    let li = document.createElement("li"); // create new list item DOM element
    let name = payload.name || 'guest';    // get name from payload or set default
    li.innerHTML = '<b>' + name + '</b>: ' + payload.message; // set li contents
    msg.value = payload.message;
    my_button.style.backgroundColor = 'red';
    ul.appendChild(li);                    // append to list
});

channel.join(); // join the channel.


let ul = document.getElementById('msg-list');        // list of messages.
let name = document.getElementById('name');          // name of message sender

// "listen" for the [Enter] keypress event to send a message:
msg.addEventListener('keypress', function (event) {
    if (event.keyCode == 13 && msg.value.length > 0) { // don't sent empty msg.
        channel.push('shout', { // send the message to the server on "shout" channel
            name: name.value,     // get value of "name" of person sending the message
            message: msg.value    // get message text (value) from msg input field.
        });
        msg.value = '';         // reset the message input field for next message.
    }
});

my_button.addEventListener('click', function (event) {
    channel.push('shout', { // send the message to the server on "shout" channel
        name: name.value,     // get value of "name" of person sending the message
        message: 'click something'    // get message text (value) from msg input field.
    });
});
