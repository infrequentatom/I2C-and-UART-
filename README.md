Professional-Grade Parameterizable UART IP Core
!(https://img.shields.io/badge/status-verified-brightgreen.svg)

A robust, full-duplex Universal Asynchronous Receiver/Transmitter (UART) IP core designed for reliable FPGA system integration.

Unlike minimal academic examples, this core addresses real-world system design challenges including Clock Domain Crossing (CDC), asynchronous data buffering, and noise immunity. It presents a clean, AXI-Stream-like FIFO interface to the host system, abstracting away the complexities of serial timing.

🚀 Key Features
Full-Duplex Operation: Simultaneous transmission and reception.

Robust Clock Domain Crossing (CDC): Integrated Asynchronous FIFOs safely bridge the high-speed system clock domain and the independent UART baud-rate domains using Gray-code pointer synchronization.

Noise-Immune Receiver:

16x Oversampling: Operates at 16x the baud rate for fine-grained timing.

Majority Voting: 3-sample majority vote logic filters out glitches on the RX line.

False Start-Bit Detection: Validates start bits at the center of the pulse to prevent false triggering.

Fully Parameterizable:

System Clock Frequency & Baud Rate.

Data Width (5-9 bits).

Parity (None, Even, Odd).

Stop Bits (1 or 2).

FIFO Depth (Configurable buffer size).

Comprehensive Error Reporting: Detects Parity, Framing, and Overrun errors.

Synthesizable: Written in clean, portable Verilog-2001.

🏗️ Architecture
The design is partitioned into four distinct modules to ensure timing closure and logical separation of concerns.mermaid graph TD subgraph "System Clock Domain" Host end

subgraph "UART IP Core"
    TX_FIFO
    RX_FIFO
    Baud
    TX_Eng
    RX_Eng
end

Host -->|Write Data| TX_FIFO
TX_FIFO -->|cdc_gray| TX_Eng
TX_Eng -->|Serial TX| UART_TX_Pin

UART_RX_Pin -->|Serial RX| RX_Eng
RX_Eng -->|cdc_gray| RX_FIFO
RX_FIFO -->|Read Data| Host

Baud -->|1x Tick| TX_Eng
Baud -->|16x Tick| RX_Eng

### Clock Domains
1.  **System Domain:** User logic interacts with the FIFOs using the system clock (e.g., 100 MHz).
2.  **Baud Domain (TX):** The transmitter logic runs on a locally generated 1x baud tick.
3.  **Oversample Domain (RX):** The receiver logic runs on a locally generated 16x baud tick.

---

## ⚙️ Configuration Parameters

The core is configured at instantiation time via Verilog parameters:

| Parameter | Default | Description |
| :--- | :--- | :--- |
| `P_SYS_CLK_FREQ` | `100_000_000` | Frequency of `i_sys_clk` in Hz. |
| `P_BAUD_RATE` | `115200` | Target serial baud rate. |
| `P_DATA_BITS` | `8` | Number of data bits per frame. |
| `P_PARITY_TYPE` | `0` | `0`: None, `1`: Odd, `2`: Even. |
| `P_STOP_BITS` | `1` | Number of stop bits (1 or 2). |
| `P_FIFO_DEPTH_BITS` | `4` | FIFO depth = 2^N (e.g., 4 = 16 bytes). |

---

## 🔌 Interface Signals

### System Interface (Synchronous to `i_sys_clk`)

| Signal | Direction | Description |
| :--- | :--- | :--- |
| `i_sys_rst_n` | Input | Active-low asynchronous reset. |
| `i_tx_data` | Input | Data byte to send. |
| `i_tx_write_en` | Input | Write strobe for TX FIFO. |
| `o_tx_full` | Output | Backpressure signal; do not write if high. |
| `o_rx_data` | Output | Received data byte. |
| `o_rx_valid` | Output | Indicates `o_rx_data` is valid. |
| `i_rx_read_en` | Input | Read strobe to pop data from RX FIFO. |
| `o_rx_empty` | Output | Indicates no data available to read. |

### Status Flags

| Signal | Description |
| :--- | :--- |
| `o_rx_parity_err` | Parity check failed for current byte. |
| `o_rx_framing_err` | Stop bit missing (line synchronization lost). |
| `o_rx_overrun_err` | Internal buffer full; incoming data dropped. |

---

## 📂 Project Structure

.
├── doc/                   # Design documentation and diagrams
├── rtl/                   # Synthesizable Source Code
│   ├── uart_top.v         # Top-level wrapper
│   ├── uart_tx.v          # Transmitter FSM & PISO
│   ├── uart_rx.v          # Receiver FSM, Majority Vote & SIPO
│   ├── async_fifo.v       # Gray-code CDC FIFO
│   └── baud_rate_gen.v    # Fractional baud rate generator
├── tb/                    # Simulation files
│   └── uart_tb.v          # Self-checking testbench
├── sim/                   # Makefiles / EDA scripts
└── README.md              # Project Documentation

---

## 🧪 Verification

The project includes a self-checking testbench (`tb/uart_tb.v`) that verifies:
1.  **Loopback Integrity:** Data sent TX -> RX matches exactly.
2.  **CDC Robustness:** Data passes safely between asynchronous clocks.
3.  **Error Injection:** Simulates noise/framing errors to verify error flags.

### How to Run Simulation
*(Assuming Icarus Verilog + GTKWave)*

```bash
cd sim
iverilog -o uart_sim../rtl/*.v../tb/uart_tb.v
vvp uart_sim
gtkwave dump.vcd
