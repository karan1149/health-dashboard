#### Mental health metric

The (obviously arbitrary!) mental health metric used is

```
mental_health = (elevated^2.8675) - (
          (0.5*(anxiety^6.6582)) +
          (0.5*(depressed^6.6582))
        )^0.5
```

Why are the bases and multiplicative factors are as they are?

1. They put the score on a scale between `(-100, 100)`, since the individual components vary between `{1, 2, 3, 4}` (except `elevated` for which I manually add `0.5` or `1` for truly peak experiences). Recording the lowest score on all variables maps to a `mental_health` value of `0`.
2. Very elevated days are much better than elevated days. Think: peak experiences!
3. Very depressed (anxious) days are much worse than depressed (anxious) days. On the other hand, a very depressed __or__ very anxious day is worse than a depressed __and__ anxious day. The formula for negative experiences captures these features.

#### Subjective well-being, life satisfaction, work satisfaction metrics

These metrics are also arbitrary. Additionally, they're hard to interpret -- their 0-point doesn't correspond to anything meaningful. In each case, I take the highest and lowest possible value of the scores and rescale to the range `(-100, 100)`.

Subjective well-being is a function of `elevated`, `energy`, `fun`, `dog_interaction`, `anxiety`, `conflict`, and `depressed`.

Life satisfaction is a function of `self`, `liberty`, `value_alignment`, `health`, `security`, `relationship_satisfaction`, `integrity`, `optimism`, `shame`, and `suicidality`.

Finally, work satisfaction is a function of `energy`, `mental_clarity`, `value_alignment`, `security`, `relationship_satisfaction`, `liberty`, `achievement`, `learning`, `work_depth`, and `professional_mastery`.