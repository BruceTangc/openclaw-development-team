"""
e2e_target.py — 极小测试目标：hello 函数 + 自测。

Phase 1 E2E 的真实 implementation 目标。
Developer sub-agent 将在临时测试项目中放置此文件（或其功能等价实现），
并运行自测作为 evidence。
"""


def hello(name="world"):
    """返回问候语。"""
    return "hello, " + name


def _self_test():
    """内置自测：无需 pytest，python3 直接跑即可。"""
    assert hello() == "hello, world", "default 用例失败"
    assert hello("lead") == "hello, lead", "带参用例失败"
    print("self_test PASS: hello() ->", hello())
    return True


if __name__ == "__main__":
    _self_test()
