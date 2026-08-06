# Anti-Crash Manifesto Credo Konfigürasyonu
#
# Bu dosya kod kalite kapısını tanımlar.
# `mix credo --strict` komutu bu kurallara göre çalışır.

%{
  configs: [
    %{
      name: "default",
      strict: true,
      color: true,
      checks: [
        {Credo.Check.Consistency.TabsOrSpaces, []},
        {Credo.Check.Consistency.SpaceAroundOperators, []},
        {Credo.Check.Consistency.LineEndings, []},

        # Güvenlik
        {Credo.Check.Warning.IoInspect, []},
        {Credo.Check.Warning.IExPry, []},
        {Credo.Check.Warning.OperationOnSameValues, []},
        {Credo.Check.Warning.BoolOperationOnSameValues, []},

        # Okunabilirlik
        {Credo.Check.Readability.ModuleDoc, []},
        {Credo.Check.Readability.FunctionNames, []},
        {Credo.Check.Readability.PredicateName, []},
        {Credo.Check.Readability.LargeNumbers, []},
        {Credo.Check.Readability.MultiAlias, []},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
        {Credo.Check.Readability.StringSigils, []},
        {Credo.Check.Readability.TrailingBlankLine, []},
        {Credo.Check.Readability.TrailingWhiteSpace, []},
        {Credo.Check.Readability.VariableNames, []},
        {Credo.Check.Readability.Semicolon, []},
        {Credo.Check.Readability.SinglePipe, []},

        # Refaktör fırsatları
        {Credo.Check.Refactor.DoubleBooleanNegation, []},
        {Credo.Check.Refactor.CondStatements, []},
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 12},
        {Credo.Check.Refactor.FunctionArity, max_arity: 8},
        {Credo.Check.Refactor.LongQuoteBlocks, []},
        {Credo.Check.Refactor.MapInto, []},
        {Credo.Check.Refactor.MatchInCondition, []},
        {Credo.Check.Refactor.NegatedConditionInUnless, []},
        {Credo.Check.Refactor.NegatedIfUnless, []},
        {Credo.Check.Refactor.Nesting, max_nesting: 3},
        {Credo.Check.Refactor.UnlessWithElse, []},
        {Credo.Check.Refactor.WithClauses, []},

        # Uyarılar
        {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
        {Credo.Check.Warning.RaiseInsideRescue, []},
        {Credo.Check.Warning.UnusedEnumOperation, []},
        {Credo.Check.Warning.UnusedExecOperation, []},
        {Credo.Check.Warning.UnusedFunctionReturnHelper, []},
        {Credo.Check.Warning.UnusedKeywordOperation, []},
        {Credo.Check.Warning.UnusedListOperation, []},
        {Credo.Check.Warning.UnusedPathOperation, []},
        {Credo.Check.Warning.UnusedRegexOperation, []},
        {Credo.Check.Warning.UnusedStringOperation, []},
        {Credo.Check.Warning.UnusedTupleOperation, []}
      ]
    }
  ]
}
