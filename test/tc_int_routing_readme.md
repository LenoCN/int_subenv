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

### 2.2. 验证序列 (`int_routing_sequence`)

-   **启动**: 测试用例 `tc_int_routing` 在其 `main_phase` 中创建并启动 `int_routing_sequence`。
-   **执行流程**:
    1.  序列首先调用 `int_routing_model::build()` 来构建内存中的中断路由预测模型。
    2.  接着，序列会遍历 `interrupt_map` 数组中的**每一个**中断条目。
    3.  对于每一个中断，序列执行 `check_interrupt_routing` 任务，该任务：
        -   使用 `uvm_hdl_force` 函数强制将该中断的**源RTL信号**置为有效（`1`）。
        -   等待一小段时间（例如`10ns`），以确保信号有足够的时间在设计中传播。
        -   调用 `check_dest` 辅助任务，根据模型中的预期结果，使用 `uvm_hdl_read` 函数读取**所有目标RTL信号**的当前值。
        -   将读取到的实际值与模型中的期望值进行比较。如果一个中断被路由到了非预期的目的地，或者没有被路由到预期的目的地，测试将报告一个 `UVM_ERROR`。
        -   使用 `uvm_hdl_release` 释放对源信号的强制操作，为下一次检查做准备。

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
