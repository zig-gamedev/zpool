const std = @import("std");

pub fn EmbeddedRingQueue(comptime TElement: type) type {
    const assert = std.debug.assert;

    return struct {
        const Self = @This();

        pub const Error = error{
            Empty,
            Full,
        };

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        pub const Element = TElement;

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        head: usize = 0,
        tail: usize = 0,
        storage: []Element = &.{},

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        pub fn init(buffer: []Element) Self {
            return .{ .storage = buffer };
        }

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        pub fn capacity(self: Self) usize {
            return self.storage.len;
        }

        pub fn len(self: Self) usize {
            return self.tail -% self.head;
        }

        pub fn empty(self: Self) bool {
            return self.len() == 0;
        }

        pub fn full(self: Self) bool {
            return self.len() == self.capacity();
        }

        pub fn clear(self: *Self) void {
            self.head = 0;
            self.tail = 0;
        }

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        /// Returns true if the length of `storage` can be increased via `resizeNoCopy`.
        pub fn canResize(self: *Self) bool {
            if (self.len() == 0) return true;
            const tail_index = self.tail % self.storage.len;
            const head_index = self.head % self.storage.len;
            return tail_index > head_index;
        }

        /// Replaces `storage` with `new_storage`. The caller guarantees that `new_storage`
        /// contains the same data as the previous storage (ie. it's the same region of
        /// memory but with a larger `len`, or the caller has copied the previous memory).
        pub fn resize(self: *Self, new_storage: []Element) void {
            // The backing storage can't be increased if the range of entries wraps past the end of the
            // backing buffer, as we'd be adding invalid entries into the middle of the queue.
            assert(new_storage.len >= self.storage.len and self.canResize());
            const prev_len = self.len();
            if (prev_len > 0) {
                self.head = self.head % self.storage.len;
                self.tail = self.head + prev_len;
            }

            self.storage = new_storage;
        }

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        pub fn enqueue(self: *Self, value: Element) Error!void {
            if (self.enqueueIfNotFull(value)) {
                return;
            }
            return Error.Full;
        }

        pub fn dequeue(self: *Self) Error!Element {
            var value: Element = undefined;
            if (self.dequeueIfNotEmpty(&value)) {
                return value;
            }
            return Error.Empty;
        }

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        pub fn enqueueIfNotFull(self: *Self, value: Element) bool {
            if (self.full()) {
                return false;
            }
            self.enqueueUnchecked(value);
            return true;
        }

        pub fn dequeueIfNotEmpty(self: *Self, value: *Element) bool {
            if (self.empty()) {
                return false;
            }
            self.dequeueUnchecked(value);
            return true;
        }

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        pub fn enqueueAssumeNotFull(self: *Self, value: Element) void {
            assert(!self.full());
            self.enqueueUnchecked(value);
        }

        pub fn dequeueAssumeNotEmpty(self: *Self) Element {
            assert(!self.empty());
            var value: Element = undefined;
            self.dequeueUnchecked(&value);
            return value;
        }

        // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

        pub fn enqueueUnchecked(self: *Self, value: Element) void {
            const tail_index = self.tail % self.storage.len;
            self.storage[tail_index] = value;
            self.tail +%= 1;
        }

        pub fn dequeueUnchecked(self: *Self, value: *Element) void {
            const head_index = self.head % self.storage.len;
            value.* = self.storage[head_index];
            self.head +%= 1;
        }
    };
}

//------------------------------------------------------------------------------

const expectEqual = std.testing.expectEqual;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

test "EmbeddedRingQueue basics" {
    var buffer: [16]usize = undefined;
    var queue = EmbeddedRingQueue(usize).init(buffer[0..]);

    try expectEqual(buffer.len, queue.capacity());
    try expectEqual(@as(usize, 0), queue.len());
    try expectEqual(true, queue.empty());
    try expectEqual(false, queue.full());

    for (buffer, 0..) |_, i| {
        try expectEqual(i, queue.len());
        try queue.enqueue(i);
        try expectEqual(i, buffer[i]);
    }

    try expectEqual(buffer.len, queue.capacity());
    try expectEqual(buffer.len, queue.len());
    try expectEqual(false, queue.empty());
    try expectEqual(true, queue.full());

    for (buffer, 0..) |_, i| {
        try expectEqual(buffer.len - i, queue.len());
        const j = try queue.dequeue();
        try expectEqual(i, j);
    }

    try expectEqual(buffer.len, queue.capacity());
    try expectEqual(@as(usize, 0), queue.len());
    try expectEqual(true, queue.empty());
    try expectEqual(false, queue.full());

    for (buffer, 0..) |_, i| {
        try expectEqual(i, queue.len());
        try queue.enqueue(i);
        try expectEqual(i, buffer[i]);
    }

    try expectEqual(buffer.len, queue.capacity());
    try expectEqual(buffer.len, queue.len());
    try expectEqual(false, queue.empty());
    try expectEqual(true, queue.full());

    queue.clear();

    try expectEqual(buffer.len, queue.capacity());
    try expectEqual(@as(usize, 0), queue.len());
    try expectEqual(true, queue.empty());
    try expectEqual(false, queue.full());
}

//------------------------------------------------------------------------------
