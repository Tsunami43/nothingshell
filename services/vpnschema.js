.pragma library

// One entry per NetworkManager VPN plugin: `fields` is both the form and the vpn.data key map,
// so a new technology is a new object here and no QML changes. Keys were read out of the
// installed plugin binaries, not from documentation.
//
// Field kinds: text | password | file | bool | select | int | hidden
//   secret   goes to vpn.secrets, plus a "<key>-flags" companion in vpn.data
//   def      what the plugin already assumes; a field still at its default is not written
//   always   write even when equal to def
//   falseAs  "no" writes the key, "omit" drops it — plugins differ on which they read
//   when     { key, in: [...] } or { key, nonEmpty: true }
//   accept   extensions the file picker offers first

// --- strongSwan / IKEv2 ---
// method and cert-source are two separate combos in the plugin's own UI, not one.
const STRONGSWAN = {
    id: "strongswan",
    label: "IPsec / IKEv2",
    subtext: "strongSwan — what most corporate and hosting VPNs speak",
    icon: "shield_lock",
    service: "org.freedesktop.NetworkManager.strongswan",
    package: "networkmanager-strongswan",
    fields: [
        { key: "address", kind: "text", label: "Server", required: true,
          placeholder: "vpn.example.com or 203.0.113.10" },
        { key: "certificate", kind: "file", label: "Server / CA certificate",
          accept: [".pem", ".crt", ".cer", ".der"],
          help: "The certificate that signs the gateway. Empty uses the system CA store.",
          dialogTitle: "Choose a server or CA certificate" },
        { key: "remote-identity", kind: "text", label: "Server identity",
          placeholder: "(defaults to address or certificate subject)" },

        { key: "method", kind: "select", label: "Authentication", def: "eap", always: true,
          options: [
              { value: "eap",     label: "EAP (username / password)" },
              { value: "key",     label: "Certificate" },
              { value: "eap-tls", label: "EAP-TLS" },
              { value: "psk",     label: "Pre-shared key" }
          ] },
        { key: "cert-source", kind: "select", label: "Certificate source", def: "file", always: true,
          options: [
              { value: "file",      label: "Certificate / private key" },
              { value: "agent",     label: "Certificate / ssh-agent" },
              { value: "smartcard", label: "Smartcard" }
          ],
          when: { key: "method", in: ["key", "eap-tls"] } },
        { key: "usercert", kind: "file", label: "Client certificate",
          accept: [".pem", ".crt", ".p12", ".pfx"],
          dialogTitle: "Choose a client certificate",
          when: { key: "method", in: ["key", "eap-tls"] } },
        { key: "userkey", kind: "file", label: "Private key",
          accept: [".pem", ".key", ".der", ".p12", ".pfx"],
          help: "Must match the certificate's public key. May be encrypted.",
          dialogTitle: "Choose a private key",
          when: { key: "cert-source", in: ["file"] } },

        { key: "user", kind: "text", label: "Username",
          help: "The EAP identity presented to the server",
          when: { key: "method", in: ["eap"] } },
        { key: "password", kind: "password", label: "Password", secret: true,
          help: "At least 20 characters for a pre-shared key",
          when: { key: "method", in: ["eap", "psk"] } },
        { key: "local-identity", kind: "text", label: "Local identity",
          placeholder: "(defaults to username, certificate subject or IP)" },

        { key: "virtual", kind: "bool", label: "Request an inner IP address",
          def: "yes", falseAs: "no", always: true,
          help: "Ask the server for an address out of its pool" },
        { key: "encap", kind: "bool", label: "Enforce UDP encapsulation",
          def: "no", falseAs: "no", always: true,
          help: "Helps where a firewall blocks raw ESP" },
        { key: "ipcomp", kind: "bool", label: "Use IP compression",
          def: "no", falseAs: "no", always: true },
        { key: "server-port", kind: "int", label: "Server port",
          placeholder: "(500, then 4500)", advanced: true },

        { key: "proposal", kind: "bool", label: "Custom algorithm proposals",
          def: "no", falseAs: "no", always: true, advanced: true },
        { key: "ike", kind: "text", label: "IKE proposals", placeholder: "aes256-sha256-modp2048",
          help: "Several separated by \";\"", advanced: true,
          when: { key: "proposal", in: ["yes", true] } },
        { key: "esp", kind: "text", label: "ESP proposals", placeholder: "aes256gcm16",
          advanced: true, when: { key: "proposal", in: ["yes", true] } },
        { key: "local-ts", kind: "text", label: "Local traffic selectors", advanced: true },
        { key: "remote-ts", kind: "text", label: "Remote traffic selectors", advanced: true,
          placeholder: "(defaults to 0.0.0.0/0;::/0)" }
    ]
};

// --- OpenVPN ---
// The form is for people handed a gateway and a username; anyone with a .ovpn should import it.
const OPENVPN = {
    id: "openvpn",
    label: "OpenVPN",
    subtext: "Fill in a form, or import a .ovpn file",
    icon: "vpn_lock",
    service: "org.freedesktop.NetworkManager.openvpn",
    package: "networkmanager-openvpn",
    importType: "openvpn",
    importAccept: [".ovpn", ".conf"],
    fields: [
        { key: "remote", kind: "text", label: "Gateway", required: true,
          placeholder: "vpn.example.com" },
        { key: "port", kind: "int", label: "Port", placeholder: "1194" },
        { key: "proto-tcp", kind: "bool", label: "Use TCP", def: "no", falseAs: "omit" },

        { key: "connection-type", kind: "select", label: "Authentication",
          def: "password", always: true,
          options: [
              { value: "password",     label: "Password" },
              { value: "tls",          label: "Certificates (TLS)" },
              { value: "password-tls", label: "Password with certificates" },
              { value: "static-key",   label: "Static key" }
          ] },

        { key: "ca", kind: "file", label: "CA certificate", accept: [".pem", ".crt", ".cer"],
          dialogTitle: "Choose a CA certificate",
          when: { key: "connection-type", in: ["tls", "password", "password-tls"] } },
        { key: "cert", kind: "file", label: "User certificate", accept: [".pem", ".crt", ".p12"],
          dialogTitle: "Choose a user certificate",
          when: { key: "connection-type", in: ["tls", "password-tls"] } },
        { key: "key", kind: "file", label: "Private key", accept: [".pem", ".key", ".p12"],
          dialogTitle: "Choose a private key",
          when: { key: "connection-type", in: ["tls", "password-tls"] } },
        { key: "cert-pass", kind: "password", label: "Private key password", secret: true,
          when: { key: "connection-type", in: ["tls", "password-tls"] } },

        { key: "username", kind: "text", label: "Username",
          when: { key: "connection-type", in: ["password", "password-tls"] } },
        { key: "password", kind: "password", label: "Password", secret: true,
          when: { key: "connection-type", in: ["password", "password-tls"] } },

        { key: "static-key", kind: "file", label: "Static key", accept: [".key", ".txt"],
          dialogTitle: "Choose a static key",
          when: { key: "connection-type", in: ["static-key"] } },
        { key: "static-key-direction", kind: "select", label: "Key direction", def: "",
          options: [{ value: "", label: "None" }, { value: "0", label: "0" }, { value: "1", label: "1" }],
          when: { key: "connection-type", in: ["static-key"] } },

        { key: "ta", kind: "file", label: "TLS auth key", accept: [".key", ".pem"],
          dialogTitle: "Choose a TLS auth key",
          when: { key: "connection-type", in: ["tls", "password", "password-tls"] } },
        { key: "ta-dir", kind: "select", label: "TLS auth key direction", def: "",
          options: [{ value: "", label: "None" }, { value: "0", label: "0" }, { value: "1", label: "1" }],
          when: { key: "ta", nonEmpty: true } },

        { key: "cipher", kind: "select", label: "Cipher", def: "",
          options: [
              { value: "", label: "Plugin default" },
              { value: "AES-256-GCM", label: "AES-256-GCM" },
              { value: "AES-128-GCM", label: "AES-128-GCM" },
              { value: "AES-256-CBC", label: "AES-256-CBC" },
              { value: "AES-128-CBC", label: "AES-128-CBC" }
          ] },
        { key: "auth", kind: "select", label: "HMAC digest", def: "",
          options: [
              { value: "", label: "Plugin default" },
              { value: "SHA256", label: "SHA-256" },
              { value: "SHA512", label: "SHA-512" },
              { value: "SHA1", label: "SHA-1" }
          ] },
        { key: "remote-cert-tls", kind: "select", label: "Verify peer certificate usage", def: "",
          options: [
              { value: "", label: "No" },
              { value: "server", label: "Server" },
              { value: "client", label: "Client" }
          ], advanced: true },
        { key: "verify-x509-name", kind: "text", label: "Verify peer name", advanced: true },
        { key: "comp-lzo", kind: "select", label: "LZO compression", def: "",
          options: [
              { value: "", label: "Off" },
              { value: "yes", label: "On" },
              { value: "adaptive", label: "Adaptive" }
          ], advanced: true },
        { key: "dev-type", kind: "select", label: "Device type", def: "",
          options: [
              { value: "", label: "Automatic" },
              { value: "tun", label: "tun" },
              { value: "tap", label: "tap" }
          ], advanced: true },
        { key: "tunnel-mtu", kind: "int", label: "MTU", advanced: true },
        { key: "reneg-seconds", kind: "int", label: "Renegotiate every (s)", advanced: true },
        { key: "float", kind: "bool", label: "Accept packets from any address",
          def: "no", falseAs: "omit", advanced: true }
    ]
};

// --- L2TP / IPsec ---
// What SoftEther speaks out of the box. Two separate credentials: the IPsec shared key and the
// account password. Keys read out of nm-l2tp-service and its editor plugin (1.52.2).
const L2TP = {
    id: "l2tp",
    label: "L2TP / IPsec",
    subtext: "SoftEther, and anything that dials like Windows does",
    icon: "vpn_key",
    service: "org.freedesktop.NetworkManager.l2tp",
    package: "networkmanager-l2tp",
    fields: [
        { key: "gateway", kind: "text", label: "Server", required: true,
          placeholder: "vpn.example.com or 203.0.113.10" },

        { key: "user-auth-type", kind: "select", label: "Account authentication",
          def: "password", always: true,
          options: [
              { value: "password", label: "Username / password" },
              { value: "tls",      label: "Certificate" }
          ] },
        { key: "user", kind: "text", label: "Username", required: true,
          help: "On SoftEther, user@hub when the account is not on the default hub",
          when: { key: "user-auth-type", in: ["password"] } },
        { key: "password", kind: "password", label: "Password", secret: true,
          help: "The account password, not the IPsec shared key",
          when: { key: "user-auth-type", in: ["password"] } },
        { key: "user-ca", kind: "file", label: "CA certificate", accept: [".pem", ".crt", ".cer"],
          dialogTitle: "Choose a CA certificate",
          when: { key: "user-auth-type", in: ["tls"] } },
        { key: "user-cert", kind: "file", label: "User certificate", accept: [".pem", ".crt", ".p12"],
          dialogTitle: "Choose a user certificate",
          when: { key: "user-auth-type", in: ["tls"] } },
        { key: "user-key", kind: "file", label: "Private key", accept: [".pem", ".key", ".p12"],
          dialogTitle: "Choose a private key",
          when: { key: "user-auth-type", in: ["tls"] } },
        { key: "user-certpass", kind: "password", label: "Private key password", secret: true,
          when: { key: "user-auth-type", in: ["tls"] } },
        { key: "domain", kind: "text", label: "NT domain", advanced: true },

        // Optional in the plugin, but off it is plaintext PPP over the internet.
        { key: "ipsec-enabled", kind: "bool", label: "Secure the tunnel with IPsec",
          def: "yes", falseAs: "no", always: true },
        { key: "machine-auth-type", kind: "select", label: "IPsec authentication",
          def: "psk", always: true,
          options: [
              { value: "psk", label: "Pre-shared key" },
              { value: "tls", label: "Certificate" }
          ],
          when: { key: "ipsec-enabled", in: ["yes"] } },
        { key: "ipsec-psk", kind: "password", label: "IPsec pre-shared key", secret: true,
          help: "SoftEther calls this the IPsec secret; its default is often \"vpn\"",
          when: { key: "machine-auth-type", in: ["psk"] } },
        { key: "machine-ca", kind: "file", label: "IPsec CA certificate",
          accept: [".pem", ".crt", ".cer"], dialogTitle: "Choose an IPsec CA certificate",
          when: { key: "machine-auth-type", in: ["tls"] } },
        { key: "machine-cert", kind: "file", label: "IPsec machine certificate",
          accept: [".pem", ".crt", ".p12"], dialogTitle: "Choose a machine certificate",
          when: { key: "machine-auth-type", in: ["tls"] } },
        { key: "machine-key", kind: "file", label: "IPsec machine key",
          accept: [".pem", ".key", ".p12"], dialogTitle: "Choose a machine key",
          when: { key: "machine-auth-type", in: ["tls"] } },
        { key: "machine-certpass", kind: "password", label: "IPsec key password", secret: true,
          when: { key: "machine-auth-type", in: ["tls"] } },

        { key: "ipsec-forceencaps", kind: "bool", label: "Enforce UDP encapsulation",
          def: "no", falseAs: "no",
          help: "Turn on when the connection stalls behind NAT",
          when: { key: "ipsec-enabled", in: ["yes"] } },
        { key: "ipsec-remote-id", kind: "text", label: "IPsec remote ID", advanced: true,
          when: { key: "ipsec-enabled", in: ["yes"] } },
        { key: "ipsec-group-name", kind: "text", label: "IPsec group name", advanced: true,
          when: { key: "ipsec-enabled", in: ["yes"] } },
        { key: "ipsec-ikev2", kind: "bool", label: "Use IKEv2 key exchange",
          def: "no", falseAs: "no", advanced: true,
          when: { key: "ipsec-enabled", in: ["yes"] } },
        { key: "ipsec-pfs", kind: "bool", label: "Disable perfect forward secrecy",
          def: "no", falseAs: "no", advanced: true,
          when: { key: "ipsec-enabled", in: ["yes"] } },
        { key: "ipsec-ipcomp", kind: "bool", label: "Use IP compression",
          def: "no", falseAs: "no", advanced: true,
          when: { key: "ipsec-enabled", in: ["yes"] } },
        { key: "ipsec-ike", kind: "text", label: "Phase 1 algorithms", advanced: true,
          placeholder: "aes128-sha1-modp1024", when: { key: "ipsec-enabled", in: ["yes"] } },
        { key: "ipsec-esp", kind: "text", label: "Phase 2 algorithms", advanced: true,
          placeholder: "aes128-sha1", when: { key: "ipsec-enabled", in: ["yes"] } },

        // PPP inside the tunnel negotiates its own auth; the refusals force a server's hand.
        { key: "refuse-eap", kind: "bool", label: "Refuse EAP", def: "no", falseAs: "omit", advanced: true },
        { key: "refuse-pap", kind: "bool", label: "Refuse PAP", def: "no", falseAs: "omit", advanced: true },
        { key: "refuse-chap", kind: "bool", label: "Refuse CHAP", def: "no", falseAs: "omit", advanced: true },
        { key: "refuse-mschap", kind: "bool", label: "Refuse MS-CHAP", def: "no", falseAs: "omit", advanced: true },
        { key: "refuse-mschapv2", kind: "bool", label: "Refuse MS-CHAPv2", def: "no", falseAs: "omit", advanced: true },
        { key: "require-mppe", kind: "bool", label: "Require MPPE encryption",
          def: "no", falseAs: "omit", advanced: true },
        { key: "mtu", kind: "int", label: "MTU", placeholder: "1400", advanced: true },
        { key: "mru", kind: "int", label: "MRU", placeholder: "1400", advanced: true }
    ]
};

// Native to NetworkManager: no plugin, no vpn.data, and only a .conf carries the peers and keys.
const WIREGUARD = {
    id: "wireguard",
    label: "WireGuard",
    subtext: "Import a .conf — NetworkManager builds the profile",
    icon: "bolt",
    importOnly: true,
    importType: "wireguard",
    importAccept: [".conf"],
    fields: []
};

var types = [STRONGSWAN, OPENVPN, L2TP, WIREGUARD];

function byId(id) {
    for (const t of types) if (t.id === id) return t;
    return null;
}
function byService(service) {
    for (const t of types) if (t.service && t.service === service) return t;
    return null;
}

function truthy(v) { return v === true || v === "yes" || v === "true"; }

// Marks a secret the user cleared on purpose, as opposed to one they just did not retype.
const CLEAR_PREFIX = "__clear:";
function clearKey(key) { return CLEAR_PREFIX + key; }

// Defaults folded in, so a `when` clause can test a field nobody has touched yet.
// An unreachable field contributes nothing — neither its default nor a stale earlier value —
// which is what keeps the private key row out of an EAP form. A `when` may only name a field
// declared before it.
function resolve(type, rawValues) {
    const raw = rawValues ?? {};
    const out = {};
    for (const f of (type.fields ?? [])) {
        if (!clauseHolds(f.when, out)) continue;
        const v = raw[f.key];
        if (v !== undefined && v !== null && v !== "") out[f.key] = v;
        else if (f.def !== undefined && f.def !== "") out[f.key] = f.def;
    }
    return out;
}

// A field is on screen when its `when` clause holds against the values entered so far.
function fieldVisible(f, values, showAdvanced) {
    if (f.kind === "hidden") return false;
    if (f.advanced && !showAdvanced) return false;
    return clauseHolds(f.when, values);
}
function clauseHolds(when, values) {
    if (!when) return true;
    const v = values[when.key] ?? "";
    if (when.nonEmpty) return ("" + v).trim() !== "";
    for (const opt of when.in ?? []) if (opt === v) return true;
    return false;
}

// vpn.data and vpn.secrets from the form. `existing` is what an edit was loaded from, and matters
// because `nmcli con modify vpn.data` replaces the dict rather than merging into it: keys this
// schema does not know are carried across, and a blank secret box means "unchanged", not "erase"
// (secrets are never read back, so every password box starts empty).
function build(type, rawValues, existing) {
    const values = resolve(type, rawValues);
    const data = {}, secrets = {}, cleared = [];
    const prev = existing ?? {};
    const owned = {};
    for (const f of (type.fields ?? [])) {
        owned[f.key] = true;
        if (f.secret) owned[f.key + "-flags"] = true;
    }
    for (const k of Object.keys(prev)) if (!owned[k]) data[k] = prev[k];

    for (const f of (type.fields ?? [])) {
        if (!clauseHolds(f.when, values)) continue;
        let v = values[f.key];
        if (v === undefined || v === null) v = f.def ?? "";
        if (f.kind === "bool") {
            const on = truthy(v);
            if (!on && f.falseAs === "omit") continue;
            v = on ? "yes" : "no";
        }
        v = ("" + v).trim();
        if (v === "") {
            if (!f.secret) continue;
            const flags = f.key + "-flags";
            // Left blank on a profile that already holds this secret: keep both.
            if (prev[flags] !== undefined) data[flags] = prev[flags];
            else if ((rawValues ?? {})[CLEAR_PREFIX + f.key]) cleared.push(f.key);
            continue;
        }
        if (!f.always && v === (f.def ?? "")) continue;
        if (f.secret) {
            secrets[f.key] = v;
            // 0 = stored by NM. No secret agent runs here, so "always ask" could never be answered.
            data[f.key + "-flags"] = "0";
        } else {
            data[f.key] = v;
        }
    }
    return { data: data, secrets: secrets, cleared: cleared };
}

// Required fields still empty: the submit button's gate, and its subtext when disabled.
function missingRequired(type, rawValues) {
    const values = resolve(type, rawValues);
    const out = [];
    for (const f of (type.fields ?? [])) {
        if (!f.required || !clauseHolds(f.when, values)) continue;
        if (("" + (values[f.key] ?? "")).trim() === "") out.push(f.label);
    }
    return out;
}

// An unescaped comma makes nmcli reject the whole dict. Backslash first, or we escape our escapes.
function escVal(v) { return ("" + v).replace(/\\/g, "\\\\").replace(/,/g, "\\,"); }
function dictStr(o) {
    const parts = [];
    for (const k of Object.keys(o)) parts.push(k + "=" + escVal(o[k]));
    return parts.join(", ");
}

// nmcli prints the dict on one line and a value may itself contain ", ", so cut only where a
// new "key =" begins.
function parseDict(s) {
    const out = {};
    for (const part of ("" + (s || "")).split(/,\s*(?=[A-Za-z0-9_.-]+\s*=)/)) {
        const i = part.indexOf("=");
        if (i === -1) continue;
        out[part.slice(0, i).trim()] =
            part.slice(i + 1).trim().replace(/\\,/g, ",").replace(/\\\\/g, "\\");
    }
    return out;
}
