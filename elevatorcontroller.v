//==========================================================================
// Copyright (c) 2026 Huzaifa
//==========================================================================
//
// FILE NAME    : elevatorcontroller.v
// PROJECT      : FPGA-Based 4-Floor Elevator Controller
// TYPE         : RTL Design (Moore FSM)
// LANGUAGE     : Verilog HDL
//
// UNIVERSITY   : National University of Sciences and Technology (NUST)
// DEPARTMENT   : Electrical Engineering
//
// AUTHOR       : Huzaifa
// EMAIL        : huzaifa.e19@gmail.com
//
//==========================================================================
//
// RELEASE HISTORY
//
// VERSION   DATE         AUTHOR      DESCRIPTION
// -------   ----------   ----------  --------------------------------------
// 1.0       07-Jul-2026  Huzaifa     Initial project release
//
//==========================================================================
//
// KEYWORDS
// Elevator Controller, FPGA, Verilog HDL, Moore FSM, RTL Design,
// Digital Design, Sequential Logic, Floor Request Scheduling,
// Door Control, Synchronous System
//
//==========================================================================
//
// PURPOSE
// This project implements a synthesizable 4-floor Elevator Controller using
// Verilog HDL based on a Moore Finite State Machine (FSM). The controller
// is intended for FPGA implementation and demonstrates the design of a
// synchronous digital control system for elevator operation.
//
// The controller accepts multiple floor requests, determines the target
// floor, controls upward and downward movement, manages door operation,
// and indicates system busy status while servicing requests.
//
// Main Features:
//   • 4-Floor Elevator Control
//   • Moore FSM Architecture
//   • Multiple Floor Request Handling
//   • Automatic Direction Selection
//   • Floor-by-Floor Movement
//   • Programmable Movement Timing
//   • Programmable Door Open Timing
//   • Busy Status Indication
//   • Synthesizable RTL Design
//   • FPGA-Oriented Implementation
//


module elevatorcontroller(
    input clk,
    input reset,
    input [3:0] request,
    output reg motorup,
    output reg motordown,
    output reg dooropen,
    output reg busy,
    output reg [1:0] currentfloor
);

parameter DOORTIME = 20;   
parameter MOVETIME = 10;   

reg [2:0] state;
reg [2:0] nextstate;

reg [1:0] targetfloor;
reg [3:0] requests;        // Stores all pending floor requests

reg [7:0] movecounter;
reg [7:0] doorcounter;

// FSM States
localparam S0 = 3'b000,    // Idle
           S1 = 3'b001,    // Decide direction
           S2 = 3'b010,    // Move up
           S3 = 3'b011,    // Move down
           S4 = 3'b100,    // Door open
           S5 = 3'b101;    // Door close


always @(posedge clk or posedge reset) begin
    if (reset) begin
        movecounter <= 0;
        doorcounter <= 0;
    end
    else begin
        // Count while elevator is moving
        if (state == S2 || state == S3)
            movecounter <= movecounter + 1;
        else
            movecounter <= 0;

        // Count while door is open
        if (state == S4)
            doorcounter <= doorcounter + 1;
        else
            doorcounter <= 0;
    end
end

// State Register

always @(posedge clk or posedge reset) begin
    if (reset)
        state <= S0;
    else
        state <= nextstate;
end


// Next State Logic

always @(*) begin
    nextstate = state;

    case (state)

        // Wait until any request arrives
        S0:
            if (requests != 4'b0000 || request != 4'b0000)
                nextstate = S1;

        // Decide whether to move up, down or open door
        S1:
            if (targetfloor > currentfloor)
                nextstate = S2;
            else if (targetfloor < currentfloor)
                nextstate = S3;
            else
                nextstate = S4;

        // Move up one floor at a time
        S2:
            if (movecounter >= MOVETIME) begin
                if (currentfloor + 2'd1 == targetfloor)
                    nextstate = S4;
                else
                    nextstate = S1; // Re-evaluate direction for multi-floor travel
            end

        // Move down one floor at a time
        S3:
            if (movecounter >= MOVETIME) begin
                if (currentfloor - 2'd1 == targetfloor)
                    nextstate = S4;
                else
                    nextstate = S1; // Re-evaluate direction for multi-floor travel
            end

        // Keep door open for DOORTIME cycles
        S4:
            if (doorcounter >= DOORTIME)
                nextstate = S5;

        // Close door and check for more requests
        S5:
            if (requests != 4'b0000)
                nextstate = S1;
            else
                nextstate = S0;

        default:
            nextstate = S0;

    endcase
end


// Output Logic (Moore FSM)

always @(*) begin
    motorup   = 0;
    motordown = 0;
    dooropen  = 0;
    busy      = 0;

    case (state)

        S1:
            busy = 1;

        S2: begin
            motorup = 1;
            busy = 1;
        end

        S3: begin
            motordown = 1;
            busy = 1;
        end

        S4: begin
            dooropen = 1;
            busy = 1;
        end

        S5:
            busy = 1;

    endcase
end


// Datapath Logic

always @(posedge clk or posedge reset) begin
    if (reset) begin
        requests     <= 4'b0000;
        currentfloor <= 2'd0;
        targetfloor  <= 2'd0;
    end
    else begin

        // Latch every new floor request
        requests <= requests | request;

        case (state)

            // Select the next floor to be served
           
            S1: begin
                if (requests[0])
                    targetfloor <= 2'd0;
                else if (requests[1])
                    targetfloor <= 2'd1;
                else if (requests[2])
                    targetfloor <= 2'd2;
                else if (requests[3])
                    targetfloor <= 2'd3;
            end

            // Safely increment currentfloor exactly once when timer expires
            S2: begin
                if (movecounter >= MOVETIME)
                    currentfloor <= currentfloor + 2'd1;
            end

            // Safely decrement currentfloor exactly once when timer expires
            S3: begin
                if (movecounter >= MOVETIME)
                    currentfloor <= currentfloor - 2'd1;
            end

            //Safe synthesis-friendly bit-clearing using a bitwise mask
            S5: begin
                requests <= requests & ~(4'b0001 << targetfloor);
            end

        endcase
    end
end

endmodule
