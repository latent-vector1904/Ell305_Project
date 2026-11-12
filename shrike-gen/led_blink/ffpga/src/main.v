// led_blink — 1 Hz square wave on the Shrike Lite FPGA user LED
// and on header pin F0 so a logic analyzer can see the same waveform.
//
// LED   : FPGA GPIO16, package pin 7, onboard LED (active high, through R6)
// probe : FPGA GPIO0,  package pin 13, silkscreen F0, header J2 pin 16
// Clock : SLG47910 internal 50 MHz oscillator

(* top *) module led_blink (
  (* iopad_external_pin, clkbuf_inhibit *) input  clk,
  (* iopad_external_pin *) output LED,
  (* iopad_external_pin *) output LED_en,
  (* iopad_external_pin *) output probe,
  (* iopad_external_pin *) output probe_en,
  (* iopad_external_pin *) output clk_en
);

  // 50 MHz / 25_000_000 = 2 toggles per second → 1 Hz square wave.
  localparam integer HALF_PERIOD = 25_000_000;

  reg [24:0] counter;
  reg        blink;

  assign clk_en   = 1'b1;
  assign LED_en   = 1'b1;
  assign probe_en = 1'b1;
  assign LED      = blink;
  assign probe    = blink;

  always @(posedge clk) begin
    if (counter == HALF_PERIOD - 1) begin
      counter <= 25'd0;
      blink   <= ~blink;
    end else begin
      counter <= counter + 25'd1;
    end
  end

endmodule
