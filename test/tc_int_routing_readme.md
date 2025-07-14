# 中断路由功能验证测试用例 (tc_int_routing) 说明

## 1. 测试用例目标

本测试用例 (`tc_int_routing`) 的核心目标是**自动验证**设计中所有中断信号的路由功能是否符合预期。

验证基于 `中断向量表-iosub-V0.5.csv` 文件中定义的路由规则，通过在UVM（Universal Verification Methodology）环境中模拟中断触发，并检查中断信号是否被正确地路由到指定的目的地（如AP, SCP, MCP, IMU等）。

## 2. 实现原理

本测试用例通过一个核心的UVM Sequence (`int_routing_sequence`) 来实现自动化验证。其工作流程如下：

### 2.1. 中断预测模型 (`int_routing_model`)

-   **数据来源**: `seq/int_routing_model.sv` 文件中定义了一个名为 `int_routing_model` 的类，它相当于一个**中断路由预测数据库**。这个模型的数据完全基于 `中断向量表-iosub-V0.5.csv` 文件。
-   **数据结构**: 模型内部使用一个静态数组 `interrupt_map[]` 来存储每一个中断的详细信息。每个数组元素都是一个 `interrupt_info_s` 结构体，包含了中断名、索引、所属中断组、RTL源路径以及所有可能的目标（AP, SCP, MCP等）的路由信息和检查路径。
-   **自动化构建**: `build()` 函数负责将CSV中的信息转换为SystemVerilog的数据结构，填充 `interrupt_map` 数组。

### 2.2. 全局监控与检查机制

为了解决瞬时错误中断（毛刺）可能被遗漏的问题，我们引入了基于`uvm_monitor`和`uvm_scoreboard`的全局被动检查机制。

-   **中断监视器 (`int_monitor`)**:
    -   在整个仿真过程中，`int_monitor` **持续不断地**监视所有中断目标总线。
    -   一旦检测到任何中断信号变为有效，它会立即捕获该事件，并将其封装成一个 `int_transaction` 事务，然后通过 `uvm_analysis_port` 广播出去。

-   **中断记分板 (`int_scoreboard`)**:
    -   `int_scoreboard` 订阅 `int_monitor` 广播的事务。
    -   每当接收到一个中断事务，记分板会检查此中断是否在预期之中。

-   **验证序列 (`int_routing_sequence`)**:
    -   `int_routing_sequence` 的角色被简化为**中断触发器**。
    -   在通过 `uvm_hdl_force` 触发一个中断**之前**，它会先调用 `int_scoreboard::add_expected()` 函数，在记分板中“登记”它将要触发的中断及其预期的目的地。
    -   触发中断后，它不再负责检查，而是相信 `int_monitor` 和 `int_scoreboard` 会完成这项工作。

### 2.3. 工作流程总结

1.  `tc_int_routing` 启动 `int_routing_sequence`。
2.  `int_monitor` 开始在后台持续监控所有中断目标总线。
3.  `int_routing_sequence` 遍历中断模型，对于每个中断：
    a.  调用 `int_scoreboard::add_expected()`，告知记分板：“我即将触发中断X，它应该被路由到目的地Y和Z。”
    b.  `force` 中断X的源信号。
4.  `int_monitor` 检测到目的地Y和Z上的中断信号变为有效，并发送通知给 `int_scoreboard`。
5.  `int_scoreboard` 收到通知，发现这与预期匹配，标记为成功。
6.  如果在任何时候 `int_monitor` 检测到一个**未被登记**的中断（例如，由于设计错误，中断X被错误地路由到了目的地A），`int_scoreboard` 将立即报告一个 `UVM_ERROR`，指出这是一个非预期的中断。
7.  在测试结束时，`int_scoreboard` 会进行检查，如果任何登记过的预期中断**从未被检测到**，它也会报告 `UVM_ERROR`，指出有中断丢失。

## 3. 如何扩展

此框架具有良好的可扩展性。当 `中断向量表-iosub-V0.5.csv` 更新时，您只需更新 `seq/int_routing_model.sv` 文件即可，无需修改测试用例或sequence代码。

扩展步骤如下：

1.  **打开 `seq/int_routing_model.sv` 文件**。
2.  **找到对应的中断组**（例如 `// --- Start of CSUB interrupts ---`）。如果是一个新的中断组，请参考现有格式添加新的部分。
3.  **添加或修改中断条目**: 根据CSV文件中的新行或修改过的行，添加或修改对应的 `interrupt_map.push_back(...)` 语句。请确保 `name`, `index`, `group` 以及所有 `to_...` 和 `rtl_path_...` 字段都与CSV文件和RTL设计保持一致。

## 4. 注意事项

-   **RTL路径占位符**: 当前 `int_routing_model.sv` 中的所有RTL路径（`rtl_path_src` 和 `rtl_path_...`）都是**占位符**（例如 `"top_tb.int_harness.u_dut.iosub_interrupts[0]"`）。您**必须**在获得最终的RTL层次结构（通常在 `tb/int_harness.sv` 中定义）后，将这些占位符更新为实际的RTL信号路径，否则测试将无法正确运行。
-   **“Possible”路由**: 对于CSV中标记为 "Possible" 的路由，当前模型将其视为 "YES" (即预期会路由)。这是为了确保最大程度的验证覆盖。
-   **仿真时间**: 由于该测试用例会遍历所有已知中断，其仿真时间可能会较长。可以通过在 `test/tc_int_routing.sv` 中调整 `#5us` 的延时来控制总的仿真时长。
