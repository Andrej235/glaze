const std = @import("std");

const dynString = @import("utils/dyn_string.zig");
const DynString = dynString.DynString;
const CError = dynString.CError;

pub fn main() !void {
    const userName: *DynString = try DynString.initConstText("Pera");
    const userLastName: *DynString = try DynString.initConstText("Pera");

    userName.print();
    userLastName.print();
}
