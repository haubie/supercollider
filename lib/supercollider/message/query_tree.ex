defmodule SuperCollider.Message.QueryTree do
    @moduledoc """
    A representation of a group's node subtree.

    The `children:` key holds a list of nodes which are either:
    - `%{node_type: :group, ...}` which represents a group node
    - `%{node_type: :synth, ...}` which represents a synth node.
    """

    defstruct [
        :flag,
        :group_node_id,
        :num_children,
        :children
    ]

    @doc """
    Parses OSC arguments in the following order:

    1. `flag:` if synth control values are included 1, else 0
    2. `group_node_id:` node ID of the requested group
    3. `num_children:` number of child nodes contained within the requested group
    4. `children:` the nodes in the sub-tree.
    """
    def parse(res_data) do
        IO.inspect res_data, label: "QUERY TREE"
        res_data
        |> parse_head()
        |> parse_children()
    end

    defp parse_head([flag, group_node_id, num_children | rest]=_res_data) do  
        {%__MODULE__{flag: flag, group_node_id: group_node_id, num_children: num_children}, rest}
    end

    # No children
    defp parse_children({query_tree, _children}) when query_tree.num_children == 0, do: query_tree

    defp parse_children({query_tree, children}) do
        children = parse_child(children, query_tree.flag, [], query_tree.num_children)
        %{query_tree | children: children}
    end

    defp parse_child(_children, _flag, acc, 0), do: acc

    # Child is a synth
    defp parse_child([node_id, -1, synthdef_name | rest]=_children, flag, acc, rem_children) do
        {rem_data, child_controls} =
            if (flag == 1) do
                [num_controls | control_data]=rest
                maybe_parse_child_controls(control_data, flag, [], num_controls) 
            else
                {rest, []}
            end
                
        acc = acc ++ [%{node_id: node_id, node_type: :synth, num_children: length(child_controls), synth_name: synthdef_name, controls: child_controls}]
        parse_child(rem_data, flag, acc, rem_children-1)
    end

    # This is an empty group
    defp parse_child([node_id, 0 | rest]=_children, flag, acc, rem_children) do
        acc = acc ++ [%{group_node_id: node_id, node_type: :group, num_children: 0, children: []}]
        parse_child(rest, flag, acc, rem_children-1)
    end

    # This is group
    defp parse_child([node_id, num_children | rest]=_children, flag, acc, rem_children) when num_children > 0 do
        children = parse_child(rest, flag, [], num_children)
        acc = acc ++ [%{group_node_id: node_id, node_type: :group, num_children: num_children, children: children}]
        parse_child(rest, flag, acc, rem_children-1)
    end

    # No child control to pass
    defp maybe_parse_child_controls(control_data, 0, _acc, _rem_children), do: {control_data, nil}

    # Has child control(s) to pass
    defp maybe_parse_child_controls(control_data, 1, acc, 0), do: {control_data, acc}

    # Has child control(s) to pass
    defp maybe_parse_child_controls([control, value | rest]=_control_data, 1, acc, rem_children) do
        acc = acc ++ [%{control: control, value: value}]
        maybe_parse_child_controls(rest, 1, acc, rem_children-1) 
    end

end