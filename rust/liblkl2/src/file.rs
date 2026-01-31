pub struct FilePending {}

pub enum FileStatus {
    Unint,    // 没有文件
    Pending,  // 正在解析
    Complete, // 解析完成
    Error,    //解析出错
}

pub struct Logs {}

/// 在后台打开一个新文件
/// 目前只打算支持一个实例，所以老的会把新的踢掉
pub fn open(path: &str) {
    todo!()
}

/// 获取当前文件状态
pub fn status(id: usize) -> FileStatus {
    todo!()
}

pub fn logs(filter: &str, limit: u32, offset: u32) -> Logs {
    todo!()
}
