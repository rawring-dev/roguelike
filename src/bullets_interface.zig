pub fn Interface(T: type, BulletType: type) type {
    return struct {
        const Self = @This();
        ptr: *T,
        vtable: *const VTable,

        const VTable = struct {
            append: *const fn (*T, BulletType) error{OutOfMemory}!void,
        };
        pub fn append(self: *const Self, bullet: BulletType) error{OutOfMemory}!void {
            return self.vtable.append(self.ptr, bullet);
        }
    };
}
