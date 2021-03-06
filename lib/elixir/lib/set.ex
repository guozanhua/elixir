defmodule Set do
  @moduledoc %S"""
  This module specifies the Set API expected to be
  implemented by different representations.

  It also provides functions that redirect to the
  underlying Set, allowing a developer to work with
  different Set implementations using one API.

  To create a new set, use the `new` functions defined
  by each set type:

      HashSet.new  #=> creates an empty HashSet

  For simplicity's sake, in the examples below every time
  `new` is used, it implies one of the module-specific
  calls like above.

  ## Protocols

  Sets are required to implement the `Enumerable` protocol,
  allowing one to write:

      Enum.each(set, fn k ->
        IO.inspect k
      end)

  ## Match

  Sets are required to implement all operations
  using the match (`===`) operator. Any deviation from
  this behaviour should be avoided and explicitly documented.
  """

  use Behaviour

  @type value :: any
  @type values :: [ value ]
  @type t :: tuple

  defcallback new :: t
  defcallback new(Enum.t) :: t
  defcallback new(Enum.t, (any -> any)) :: t
  defcallback delete(t, value) :: t
  defcallback difference(t, t) :: t
  defcallback disjoint?(t, t) :: boolean
  defcallback empty(t) :: t
  defcallback equal?(t, t) :: boolean
  defcallback intersection(t, t) :: t
  defcallback member?(t, value) :: boolean
  defcallback put(t, value) :: t
  defcallback reduce(t, Enumerable.acc, Enumerable.reducer) :: Enumerable.result
  defcallback size(t) :: non_neg_integer
  defcallback subset?(t, t) :: boolean
  defcallback to_list(t) :: list()
  defcallback union(t, t) :: t

  defmacrop target(set) do
    quote do
      if is_tuple(unquote(set)) do
        elem(unquote(set), 0)
      else
        unsupported_set(unquote(set))
      end
    end
  end

  @doc """
  Deletes `value` from `set`.

  ## Examples

      iex> s = HashSet.new([1, 2, 3])
      ...> Set.delete(s, 4) |> Enum.sort
      [1, 2, 3]

      iex> s = HashSet.new([1, 2, 3])
      ...> Set.delete(s, 2) |> Enum.sort
      [1, 3]
  """
  @spec delete(t, value) :: t
  def delete(set, value) do
    target(set).delete(set, value)
  end

  @doc """
  Returns a set that is `set1` without the members of `set2`.

  Notice this function is polymorphic as it calculates the difference
  for of any type. Each set implementation also provides a `difference`
  function, but they can only work with sets of the same type.

  ## Examples

      iex> Set.difference(HashSet.new([1,2]), HashSet.new([2,3,4])) |> Enum.sort
      [1]

  """
  @spec difference(t, t) :: t
  def difference(set1, set2) do
    target1 = target(set1)
    target2 = target(set2)

    if target1 == target2 do
      target1.difference(set1, set2)
    else
      target2.reduce(set2, { :cont, set1 }, fn v, acc ->
        { :cont, target1.delete(acc, v) }
      end) |> elem(1)
    end
  end

  @doc """
  Checks if `set1` and `set2` have no members in common.

  Notice this function is polymorphic as it checks for disjoint sets of
  any type. Each set implementation also provides a `disjoint?` function,
  but they can only work with sets of the same type.

  ## Examples

      iex> Set.disjoint?(HashSet.new([1, 2]), HashSet.new([3, 4]))
      true
      iex> Set.disjoint?(HashSet.new([1, 2]), HashSet.new([2, 3]))
      false

  """
  @spec disjoint?(t, t) :: boolean
  def disjoint?(set1, set2) do
    target1 = target(set1)
    target2 = target(set2)

    if target1 == target2 do
      target1.disjoint?(set1, set2)
    else
      target2.reduce(set2, { :cont, true }, fn member, acc ->
        case target1.member?(set1, member) do
          false -> { :cont, acc }
          _     -> { :halt, false }
        end
      end) |> elem(1)
    end
  end

  @doc """
  Returns an empty set of the same type as `set`.
  """
  @spec empty(t) :: t
  def empty(set) do
    target(set).empty(set)
  end

  @doc """
  Check if two sets are equal using `===`.

  Notice this function is polymorphic as it compares sets of
  any type. Each set implementation also provides an `equal?`
  function, but they can only work with sets of the same type.

  ## Examples

      iex> Set.equal?(HashSet.new([1, 2]), HashSet.new([2, 1, 1]))
      true
      
      iex> Set.equal?(HashSet.new([1, 2]), HashSet.new([3, 4]))
      false

  """
  @spec equal?(t, t) :: boolean
  def equal?(set1, set2) do
    target1 = target(set1)
    target2 = target(set2)

    cond do
      target1 == target2 ->
        target1.equal?(set1, set2)

      target1.size(set1) == target2.size(set2) ->
        do_subset?(target1, target2, set1, set2)

      true ->
        false
    end
  end

  @doc """
  Returns a set containing only members in common between `set1` and `set2`.

  Notice this function is polymorphic as it calculates the intersection of
  any type. Each set implementation also provides a `intersection` function,
  but they can only work with sets of the same type.

  ## Examples

      iex> Set.intersection(HashSet.new([1,2]), HashSet.new([2,3,4])) |> Enum.sort
      [2]

      iex> Set.intersection(HashSet.new([1,2]), HashSet.new([3,4])) |> Enum.sort
      []

  """
  @spec intersection(t, t) :: t
  def intersection(set1, set2) do
    target1 = target(set1)
    target2 = target(set2)

    if target1 == target2 do
      target1.intersection(set1, set2)
    else
      target1.reduce(set1, { :cont, target1.empty(set1) }, fn v, acc ->
        { :cont, if(target2.member?(set2, v), do: target1.put(acc, v), else: acc) }
      end) |> elem(1)
    end
  end

  @doc """
  Checks if `set` contains `value`.

  ## Examples

      iex> Set.member?(HashSet.new([1, 2, 3]), 2)
      true

      iex> Set.member?(HashSet.new([1, 2, 3]), 4) 
      false

  """
  @spec member?(t, value) :: boolean
  def member?(set, value) do
    target(set).member?(set, value)
  end

  @doc """
  Inserts `value` into `set` if it does not already contain it.

  ## Examples

      iex> Set.put(HashSet.new([1, 2, 3]), 3) |> Enum.sort
      [1, 2, 3]

      iex> Set.put(HashSet.new([1, 2, 3]), 4) |> Enum.sort
      [1, 2, 3, 4]

  """
  @spec put(t, value) :: t
  def put(set, value) do
    target(set).put(set, value)
  end

  @doc """
  Returns the number of elements in `set`.

  ## Examples

      iex> Set.size(HashSet.new([1, 2, 3]))
      3

  """
  @spec size(t) :: non_neg_integer
  def size(set) do
    target(set).size(set)
  end

  @doc """
  Checks if `set1`'s members are all contained in `set2`.

  Notice this function is polymorphic as it checks the subset for
  any type. Each set implementation also provides a `subset?` function,
  but they can only work with sets of the same type.

  ## Examples

      iex> Set.subset?(HashSet.new([1, 2]), HashSet.new([1, 2, 3]))
      true
      iex> Set.subset?(HashSet.new([1, 2, 3]), HashSet.new([1, 2]))
      false
  """
  @spec subset?(t, t) :: boolean
  def subset?(set1, set2) do
    target1 = target(set1)
    target2 = target(set2)

    if target1 == target2 do
      target1.subset?(set1, set2)
    else
      do_subset?(target1, target2, set1, set2)
    end
  end

  @doc """
  Converts `set` to a list.

  ## Examples

      iex> HashSet.to_list(HashSet.new([1, 2, 3])) |> Enum.sort
      [1,2,3]

  """
  @spec to_list(t) :: list
  def to_list(set) do
    target(set).to_list(set)
  end

  @doc """
  Returns a set containing all members of `set1` and `set2`.

  Notice this function is polymorphic as it calculates the union of
  any type. Each set implementation also provides a `union` function,
  but they can only work with sets of the same type.

  ## Examples

      iex> Set.union(HashSet.new([1,2]), HashSet.new([2,3,4])) |> Enum.sort
      [1,2,3,4]

  """
  @spec union(t, t) :: t
  def union(set1, set2) do
    target1 = target(set1)
    target2 = target(set2)

    if target1 == target2 do
      target1.union(set1, set2)
    else
      target2.reduce(set2, { :cont, set1 }, fn v, acc ->
        { :cont, target1.put(acc, v) }
      end) |> elem(1)
    end
  end

  defp do_subset?(target1, target2, set1, set2) do
    target1.reduce(set1, { :cont, true }, fn member, acc ->
      case target2.member?(set2, member) do
        true -> { :cont, acc }
        _    -> { :halt, false }
      end
    end) |> elem(1)
  end

  defp unsupported_set(set) do
    raise ArgumentError, message: "unsupported set: #{inspect set}"
  end
end
