module saveChart (
    input shortint chart_id,
    input Chart chart
);
endmodule

module readChartInfo (
    input shortint chart_id,
    output ChartInfo info
);
endmodule

module readChartNotes (
	input shortint chart_id,
    output Chart chart
);
endmodule
