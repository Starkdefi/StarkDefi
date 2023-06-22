use core::array::ArrayTrait;

trait ArrayTraitExt<T> {
    fn reverse(self: @Array<T>) -> Array<T>;
}

impl ArrayTraitExtImpl<T, impl TCopy: Copy<T>, impl TDrop: Drop<T>> of ArrayTraitExt<T> {
    fn reverse(self: @Array<T>) -> Array<T> {
        let mut result = ArrayTrait::<T>::new();
        let mut i = 0;

        loop {
            if i == self.len() {
                break true;
            }

            result.append(*self[self.len() - i - 1]);
            i += 1;
        };

        result
    }
}

